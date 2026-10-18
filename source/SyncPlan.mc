import Toybox.Lang;

// Decides what a sync changes; no device or network calls, so it can be unit tested.
module SyncPlan {
    // latest: newest planned tours first, each { "id" => String, "name" => String, "changed" => String? }.
    // deviceNames: names of all courses on the device.
    // appCourses: courses this app installed, each [course, name, tour id or null].
    // installedChanges: tour id => the tour's "changed" value when this app installed it.
    // toUpdate: [tour, old course] for own courses whose tour changed since install (or was installed before changes were stored).
    // keepOnlyLatest: own courses whose tour is not among the latest go to toRemove right away;
    // otherwise they go to toCheck and are removed only if Komoot no longer has the tour.
    function plan(latest, deviceNames, appCourses, installedChanges, keepOnlyLatest) {
        var lowerNames = [];
        for (var i = 0; i < deviceNames.size(); i++) {
            lowerNames.add(deviceNames[i].toLower());
        }
        var ownByTour = {};
        for (var i = 0; i < appCourses.size(); i++) {
            if (appCourses[i][2] != null) {
                ownByTour[appCourses[i][2]] = appCourses[i][0];
            }
        }

        var toAdd = [];
        var toUpdate = [];
        var latestIds = {};
        var onDevice = 0;
        for (var i = 0; i < latest.size(); i++) {
            var tour = latest[i];
            latestIds[tour["id"]] = true;
            var own = ownByTour[tour["id"]];
            var changed = tour["changed"];
            if (own != null && changed != null && !changed.equals(installedChanges[tour["id"]])) {
                toUpdate.add([tour, own]);
            } else if (own != null || isOnDevice(tour["name"], tour["id"], lowerNames)) {
                onDevice++;
            } else {
                toAdd.add(tour);
            }
        }

        var toCheck = [];
        var toRemove = [];
        for (var i = 0; i < appCourses.size(); i++) {
            var tourId = appCourses[i][2];
            if (tourId != null && !latestIds.hasKey(tourId)) {
                (keepOnlyLatest ? toRemove : toCheck).add(appCourses[i]);
            }
        }

        return { :toAdd => toAdd, :toUpdate => toUpdate, :toCheck => toCheck, :toRemove => toRemove, :onDevice => onDevice };
    }

    // Only a definite "not found" removes a course; any other answer keeps it.
    function isGone(responseCode) {
        return responseCode == 404;
    }

    // Komoot names its courses "<tour name> <tour id>" (long names "<start> ... <tour id>"); Garmin Connect uses the bare tour name.
    function isOnDevice(tourName, tourId, lowerNames) {
        var name = tourName.toLower();
        var idSuffix = " " + tourId;
        for (var i = 0; i < lowerNames.size(); i++) {
            if (lowerNames[i].equals(name) || endsWith(lowerNames[i], idSuffix)) {
                return true;
            }
        }
        return false;
    }

    // The Komoot tour id at the end of a course name, or null. Komoot ids have 9+ digits; a shorter number is a cut-off id or
    // part of the name, and reading it as an id could remove the wrong course.
    function tourIdOf(courseName) {
        var chars = courseName.toCharArray();
        var start = chars.size();
        while (start > 0 && chars[start - 1].toNumber() >= 48 && chars[start - 1].toNumber() <= 57) {
            start--;
        }
        if (chars.size() - start < 9 || start == 0 || chars[start - 1] != ' ') {
            return null;
        }
        return courseName.substring(start, chars.size());
    }

    function endsWith(text, suffix) {
        var start = text.length() - suffix.length();
        return start >= 0 && text.substring(start, text.length()).equals(suffix);
    }
}
