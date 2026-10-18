import Toybox.Lang;

// Decides what a sync changes; no device or network calls, so it can be unit tested.
module SyncPlan {
    // latest: newest planned tours first, each { "id" => String, "name" => String, "changed" => String? }.
    // deviceNames: names of all courses on the device.
    // appCourses: courses this app installed, each [course, name].
    // installedChanges: tour id => the tour's "changed" value when this app installed it.
    // toUpdate: [tour, old course] for own courses whose tour changed since install (or was installed before changes were stored).
    // toCheck: own courses whose tour is not among the latest; they go only if Komoot no longer has the tour.
    function plan(latest, deviceNames, appCourses, installedChanges) {
        var lowerNames = [];
        for (var i = 0; i < deviceNames.size(); i++) {
            lowerNames.add(deviceNames[i].toLower());
        }
        var ownByTour = {};
        for (var i = 0; i < appCourses.size(); i++) {
            var tourId = tourIdOf(appCourses[i][1]);
            if (tourId != null) {
                ownByTour[tourId] = appCourses[i][0];
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
            } else if (isOnDevice(tour["name"], tour["id"], lowerNames)) {
                onDevice++;
            } else {
                toAdd.add(tour);
            }
        }

        var toCheck = [];
        for (var i = 0; i < appCourses.size(); i++) {
            var tourId = tourIdOf(appCourses[i][1]);
            if (tourId != null && !latestIds.hasKey(tourId)) {
                toCheck.add([appCourses[i][0], appCourses[i][1], tourId]);
            }
        }

        return { :toAdd => toAdd, :toUpdate => toUpdate, :toCheck => toCheck, :onDevice => onDevice };
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

    // The Komoot tour id at the end of a course name, or null. Komoot ids have 9+ digits; a short number (a cut-off name) is not an id.
    function tourIdOf(courseName) {
        var chars = courseName.toCharArray();
        var start = chars.size();
        while (start > 0 && chars[start - 1].toNumber() >= 48 && chars[start - 1].toNumber() <= 57) {
            start--;
        }
        if (chars.size() - start < 6 || start == 0 || chars[start - 1] != ' ') {
            return null;
        }
        return courseName.substring(start, chars.size());
    }

    function endsWith(text, suffix) {
        var start = text.length() - suffix.length();
        return start >= 0 && text.substring(start, text.length()).equals(suffix);
    }
}
