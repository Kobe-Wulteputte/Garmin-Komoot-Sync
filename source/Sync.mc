import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.StringUtil;

// One sync run: log in, load the latest planned tours of the chosen sports, remove own courses whose tour Komoot no longer has, install missing and changed latest tours.
// Tours are loaded one per request: Komoot sends ~7 KB of JSON per tour and some tours are much larger (-402 on a page of 5).
class Sync {
    private const API = "https://api.komoot.de";
    // Komoot sports that can be planned (https://static.komoot.de/doc/external-api/v007/sports.html); each has a "sport_<id>" setting.
    private const SPORTS = ["racebike", "e_racebike", "mtb_easy", "e_mtb_easy", "touringbicycle", "e_touringbicycle",
        "mtb", "e_mtb", "mtb_advanced", "e_mtb_advanced", "hike", "mountaineering", "jogging"];

    private var _log;
    private var _onDone;
    private var _auth = "";
    private var _username = "";
    private var _count = 5;
    private var _sportTypes = "";
    private var _index = 0;
    private var _latest = [];
    private var _installedChanges = {};
    private var _queue = [];
    private var _toCheck = [];
    private var _onDevice = 0;
    private var _added = 0;
    private var _updated = 0;
    private var _removed = 0;
    private var _failed = 0;

    function initialize(log, onDone) {
        _log = log;
        _onDone = onDone;
    }

    function start() {
        var login = loginSettings();
        if (login == null) {
            finish("Set your Komoot email and password in the app settings");
            return;
        }
        _count = countSetting();
        _sportTypes = sportTypesSetting();
        if (_sportTypes.length() == 0) {
            finish("Turn on at least one sport in the app settings");
            return;
        }
        var stored = Storage.getValue("installedChanges");
        _installedChanges = stored == null ? {} : stored;
        log("Logging in to Komoot");
        get(API + "/v006/account/email/" + login[0] + "/", null, basic(login[0], login[1]),
            Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON, method(:onLogin));
    }

    function onLogin(code, data) {
        if (code != 200) {
            finish("Login failed (" + code + ")");
            return;
        }
        _username = data["username"];
        _auth = basic(_username, data["password"]);
        log("Loading the latest " + _count + " planned tours");
        requestLatest();
    }

    function onLatest(code, data) {
        if (code == Communications.NETWORK_RESPONSE_TOO_LARGE || code == Communications.NETWORK_RESPONSE_OUT_OF_MEMORY) {
            _failed++;
            log("Tour " + (_index + 1) + " is too large to load, skipped");
        } else if (code != 200) {
            finish("Loading tours failed (" + code + "), nothing changed");
            return;
        } else {
            var embedded = data["_embedded"];
            if (embedded == null || embedded["tours"].size() == 0) {
                applyPlan();
                return;
            }
            var tour = embedded["tours"][0];
            _latest.add({ "id" => tour["id"].toString(), "name" => tour["name"], "changed" => tour["changed_at"] });
            log(tour["name"] + " (" + tour["sport"] + ")");
        }
        _index++;
        if (_index < _count) {
            requestLatest();
        } else {
            applyPlan();
        }
    }

    function onCheck(code, data) {
        var item = _toCheck[0];
        _toCheck = _toCheck.slice(1, null);
        if (SyncPlan.isGone(code)) {
            try {
                item[0].remove();
                _removed++;
                log("Removed " + item[1]);
            } catch (e) {
                _failed++;
                log("Could not remove " + item[1]);
            }
        }
        checkNext();
    }

    // An update downloads the new course first and only then removes the old one, so a failed download keeps the old route.
    function onFit(code, data) {
        var tour = _queue[0][0];
        var oldCourse = _queue[0][1];
        _queue = _queue.slice(1, null);
        if (code == 200 && data != null) {
            _installedChanges[tour["id"]] = tour["changed"];
            Storage.setValue("installedChanges", _installedChanges);
            if (oldCourse == null) {
                _added++;
                log("Added " + tour["name"]);
            } else {
                try {
                    oldCourse.remove();
                    _updated++;
                    log("Updated " + tour["name"]);
                } catch (e) {
                    _failed++;
                    log("Updated " + tour["name"] + ", old copy not removed");
                }
            }
        } else {
            _failed++;
            log("Failed " + tour["name"] + " (" + code + ")");
        }
        installNext();
    }

    private function requestLatest() {
        get(API + "/v007/users/" + _username + "/tours/",
            { "type" => "tour_planned", "sport_types" => _sportTypes, "sort_field" => "date", "sort_direction" => "desc",
              "limit" => "1", "page" => _index.toString() },
            _auth, Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON, method(:onLatest));
    }

    private function applyPlan() {
        var deviceNames = [];
        var it = PersistedContent.getCourses();
        var course = it.next();
        while (course != null) {
            deviceNames.add(course.getName());
            course = it.next();
        }
        var appCourses = [];
        it = PersistedContent.getAppCourses();
        course = it.next();
        while (course != null) {
            appCourses.add([course, course.getName()]);
            course = it.next();
        }

        var plan = SyncPlan.plan(_latest, deviceNames, appCourses, _installedChanges);
        _onDevice = plan[:onDevice];
        _queue = plan[:toUpdate];
        var toAdd = plan[:toAdd];
        for (var i = 0; i < toAdd.size(); i++) {
            _queue.add([toAdd[i], null]);
        }
        _toCheck = plan[:toCheck];
        if (_toCheck.size() > 0) {
            log("Checking " + _toCheck.size() + " older own courses");
        }
        checkNext();
    }

    private function checkNext() {
        if (_toCheck.size() == 0) {
            installNext();
            return;
        }
        get(API + "/v007/tours/" + _toCheck[0][2], null, _auth,
            Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON, method(:onCheck));
    }

    private function installNext() {
        if (_queue.size() == 0) {
            // Two lines: the full summary is wider than the Edge 830 screen.
            log("Added " + _added + ", updated " + _updated + ", removed " + _removed);
            finish("Already on device " + _onDevice + ", failed " + _failed);
            return;
        }
        var tour = _queue[0][0];
        log("Downloading " + tour["name"]);
        get(API + "/v007/tours/" + tour["id"] + ".fit", null, _auth,
            Communications.HTTP_RESPONSE_CONTENT_TYPE_FIT, method(:onFit));
    }

    private function finish(message) {
        log(message);
        _onDone.invoke();
    }

    private function loginSettings() {
        var email = Properties.getValue("email");
        var password = Properties.getValue("password");
        if (email == null || email.length() == 0) {
            var builtIn = $.localCredentials();
            if (builtIn == null) {
                return null;
            }
            email = builtIn[0];
            password = builtIn[1];
        }
        return password == null || password.length() == 0 ? null : [email, password];
    }

    // Comma-separated ids of the sports switched on in the settings.
    private function sportTypesSetting() {
        var types = "";
        for (var i = 0; i < SPORTS.size(); i++) {
            if (Properties.getValue("sport_" + SPORTS[i]) == true) {
                types += (types.length() > 0 ? "," : "") + SPORTS[i];
            }
        }
        return types;
    }

    private function countSetting() {
        var count = Properties.getValue("count");
        if (count == null || count < 1) {
            return 5;
        }
        return count;
    }

    private function get(url, params, auth, responseType, callback) {
        Communications.makeWebRequest(url, params, {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :headers => { "Authorization" => auth },
            :responseType => responseType
        }, callback);
    }

    private function basic(user, pass) {
        return "Basic " + StringUtil.encodeBase64(user + ":" + pass);
    }

    private function log(line) {
        _log.invoke(line);
    }
}
