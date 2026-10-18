import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.StringUtil;

// Komoot's unofficial API, one request at a time. Logs in once per app run.
// Tours are loaded one per request: Komoot sends ~7 KB of JSON per tour and some tours are much larger (-402 on a page of 5).
class Komoot {
    private const API = "https://api.komoot.de";

    private var _auth = null;
    private var _username = "";
    private var _callback;

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

    // The planned tour at position `index` (newest first), or null past the last one. sportTypes null means every sport.
    // callback(code, tour)
    function fetchTour(index, sportTypes, callback) {
        var params = { "type" => "tour_planned", "sort_field" => "date", "sort_direction" => "desc",
                       "limit" => "1", "page" => index.toString() };
        if (sportTypes != null) {
            params["sport_types"] = sportTypes;
        }
        _callback = callback;
        get(API + "/v007/users/" + _username + "/tours/", params, _auth,
            Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON, method(:onTour));
    }

    function onTour(code, data) {
        var tour = null;
        if (code == 200) {
            var embedded = data["_embedded"];
            if (embedded != null && embedded["tours"].size() > 0) {
                var json = embedded["tours"][0];
                tour = {
                    "id" => json["id"].toString(), "name" => json["name"], "changed" => json["changed_at"],
                    "distance" => json["distance"], "date" => json["date"], "sport" => json["sport"]
                };
            }
        }
        _callback.invoke(code, tour);
    }

    // Installs the tour as a course. callback(code, data)
    function downloadFit(tourId, callback) {
        _callback = callback;
        get(API + "/v007/tours/" + tourId + ".fit", null, _auth,
            Communications.HTTP_RESPONSE_CONTENT_TYPE_FIT, method(:onResponse));
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

    // The course a FIT download created, from the callback's iterator.
    function downloadedCourse(data) {
        return data != null && data has :next ? data.next() : null;
    }
}
