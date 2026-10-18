import Toybox.Activity;
import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.StringUtil;
import Toybox.System;
import Toybox.Timer;

// Komoot's unofficial API, one request at a time. Logs in once per app run.
class Komoot {
    static const TIMED_OUT = -1000;
    static const RECORDING = -1001;
    private const API = "https://api.komoot.de";
    private const DOWNLOAD_TIMEOUT_S = 60;

    private var _auth = null;
    private var _username = "";
    private var _callback;
    private var _timer = null;
    private var _stalled = false;
    private var _progress = null;
    private var _seconds = 0;
    private var _bytes = null;

    // callback(ok, errorMessage)
    function login(callback) {
        if (_auth != null) {
            callback.invoke(true, null);
            return;
        }
        var login = loginSettings();
        if (login == null) {
            callback.invoke(false, "Set your Komoot email and password in the app settings");
            return;
        }
        _callback = callback;
        get(API + "/v006/account/email/" + login[0] + "/", null, basic(login[0], login[1]),
            Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON, method(:onLogin));
    }

    function onLogin(code, data) {
        if (code == 200) {
            _username = data["username"];
            _auth = basic(_username, data["password"]);
            _callback.invoke(true, null);
        } else {
            _callback.invoke(false, "Login failed (" + code + ")");
        }
    }

    // Page `page` of the planned tours, `limit` per page, newest first; an empty array past the last one.
    // sportTypes null means every sport. callback(code, tours)
    function fetchPage(page, limit, sportTypes, callback) {
        var params = { "type" => "tour_planned", "sort_field" => "date", "sort_direction" => "desc",
                       "limit" => limit.toString(), "page" => page.toString() };
        if (sportTypes != null) {
            params["sport_types"] = sportTypes;
        }
        _callback = callback;
        get(API + "/v007/users/" + _username + "/tours/", params, _auth,
            Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON, method(:onTour));
    }

    // Keeps only the fields the app uses, so the full Komoot JSON can be freed.
    function onTour(code, data) {
        var tours = [];
        if (code == 200) {
            var embedded = data["_embedded"];
            var list = embedded == null ? [] : embedded["tours"];
            for (var i = 0; i < list.size(); i++) {
                var json = list[i];
                tours.add({
                    "id" => json["id"].toString(), "name" => json["name"], "changed" => json["changed_at"],
                    "distance" => json["distance"], "date" => json["date"], "sport" => json["sport"]
                });
            }
        }
        _callback.invoke(code, tours);
    }

    // Installs the tour as a course. callback(code, data); progress(seconds, bytes) every second and whenever bytes arrive.
    // bytes stays null unless the device reports them (Garmin documents byte progress for media downloads only).
    // The Edge 840 does not install courses while an activity is recording (JSON requests still work): code is RECORDING
    // when an activity is recording, and TIMED_OUT when the device does not answer in time.
    // That request may still answer later and could not be told apart from a new one, so no further downloads are
    // started in this app run.
    function downloadFit(tourId, callback, progress) {
        _callback = callback;
        if (isRecording()) {
            callback.invoke(RECORDING, null);
            return;
        }
        if (_stalled) {
            callback.invoke(TIMED_OUT, null);
            return;
        }
        _progress = progress;
        _seconds = 0;
        _bytes = null;
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 1000, true);
        Communications.makeWebRequest(API + "/v007/tours/" + tourId + ".fit", null, {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :headers => { "Authorization" => _auth },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_FIT,
            :fileDownloadProgressCallback => method(:onBytes)
        }, method(:onFit));
    }

    function onFit(code as Number, data as Dictionary or String or PersistedContent.Iterator or Null) as Void {
        if (_timer == null) {
            return;
        }
        _timer.stop();
        _timer = null;
        _callback.invoke(code, data);
    }

    function onTick() as Void {
        _seconds++;
        if (_seconds < DOWNLOAD_TIMEOUT_S) {
            _progress.invoke(_seconds, _bytes);
            return;
        }
        _timer.stop();
        _timer = null;
        _stalled = true;
        _callback.invoke(TIMED_OUT, null);
    }

    function onBytes(transferred as Number, size as Number?) as Void {
        if (_timer != null) {
            _bytes = transferred;
            _progress.invoke(_seconds, _bytes);
        }
    }

    // Recording, or paused but not yet saved.
    static function isRecording() {
        var info = Activity.getActivityInfo();
        return info != null && info has :timerState && info.timerState != null && info.timerState != Activity.TIMER_STATE_OFF;
    }

    // The links the device has right now. Web requests go through the phone (Bluetooth) or Wi-Fi; which one a request
    // uses is not reported, so both are named when both are up.
    static function connectionText() {
        var settings = System.getDeviceSettings();
        if (!(settings has :connectionInfo)) {
            return settings.phoneConnected ? "Via phone (Bluetooth)" : "No phone connected";
        }
        var info = settings.connectionInfo;
        var phone = isConnected(info, :bluetooth);
        var wifi = isConnected(info, :wifi);
        if (phone && wifi) {
            return "Phone (Bluetooth) and Wi-Fi connected";
        }
        return phone ? "Via phone (Bluetooth)" : wifi ? "Via Wi-Fi" : "No phone or Wi-Fi connected";
    }

    private static function isConnected(info, key) {
        return info[key] != null && info[key].state == System.CONNECTION_STATE_CONNECTED;
    }

    // "Downloading 3 of 7 · 12 KB", or the seconds so far when the device reports no bytes.
    static function progressText(label, seconds, bytes) {
        return label + " · " + (bytes != null ? (bytes / 1024) + " KB" : seconds + " s");
    }

    // 404 means Komoot no longer has the tour. callback(code, data)
    function checkTour(tourId, callback) {
        _callback = callback;
        get(API + "/v007/tours/" + tourId, null, _auth,
            Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON, method(:onResponse));
    }

    function onResponse(code, data) {
        _callback.invoke(code, data);
    }

    static function isTooLarge(code) {
        return code == Communications.NETWORK_RESPONSE_TOO_LARGE || code == Communications.NETWORK_RESPONSE_OUT_OF_MEMORY;
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
}

// What this app installed:
// - "installedChanges": Komoot's changed_at per tour id at install time; a newer value means the course is stale.
// - "ownedCourses": course id => [tour id, course name]. The device may cut long course names, which also cuts the
//   tour id at the end of the name, so the id cannot always be read back from the name.
module Installed {
    function changes() {
        var stored = Storage.getValue("installedChanges");
        return stored == null ? {} : stored;
    }

    function owned() {
        var stored = Storage.getValue("ownedCourses");
        return stored == null ? {} : stored;
    }

    // course is the course the FIT download created, or null when the device did not report it.
    function remember(tour, course) {
        var all = changes();
        all[tour["id"]] = tour["changed"];
        Storage.setValue("installedChanges", all);
        if (course != null) {
            var courses = owned();
            courses[course.getId().toString()] = [tour["id"], course.getName()];
            Storage.setValue("ownedCourses", courses);
        }
    }

    // Course ids are reused by the device, so a record only counts while the name still matches.
    function tourIdFor(course, courses) {
        var entry = courses[course.getId().toString()];
        if (entry != null && course.getName().equals(entry[1])) {
            return entry[0];
        }
        return SyncPlan.tourIdOf(course.getName());
    }

    function appCourseIds() {
        var ids = {};
        var it = PersistedContent.getAppCourses();
        var course = it.next();
        while (course != null) {
            ids[course.getId().toString()] = true;
            course = it.next();
        }
        return ids;
    }

    // The course a FIT download created: from the callback's iterator (Edge 840), else the own course that was not
    // there before the download (the iterator is not available on every device).
    function newCourse(data, before) {
        if (data != null && data has :next) {
            var course = data.next();
            if (course != null) {
                return course;
            }
        }
        var it = PersistedContent.getAppCourses();
        var course = it.next();
        while (course != null) {
            if (!before.hasKey(course.getId().toString())) {
                return course;
            }
            course = it.next();
        }
        return null;
    }
}
