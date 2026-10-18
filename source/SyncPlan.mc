import Toybox.Lang;

// Decides what a sync changes; no device or network calls, so it can be unit tested.
module SyncPlan {
    // latest: newest planned tours first, each { "id" => String, "name" => String, "changed" => String? }.
    // deviceNames: names of all courses on the device.
    // appCourses: courses this app installed, each [course, name, tour id or null].
    // installedChanges: tour id => the tour's "changed" value when this app installed it.
    // toUpdate: [tour, old course] for own courses whose tour changed since install (or was installed before changes were stored).
    // duplicates: extra own courses for a tour that already has one; always removed.
    // keepOnlyLatest: own courses whose tour is not among the latest go to toRemove right away;
    // otherwise they go to toCheck and are removed only if Komoot no longer has the tour.
    function plan(latest, deviceNames, appCourses, installedChanges, keepOnlyLatest) {
        var lowerNames = [];
        for (var i = 0; i < deviceNames.size(); i++) {
            lowerNames.add(deviceNames[i].toLower());
        }

        // Own courses with a known tour id; a shortened name is matched against the latest tours.
        var owned = [];
        var ownByTour = {};
        var duplicates = [];
        for (var i = 0; i < appCourses.size(); i++) {
            var tourId = appCourses[i][2];
            if (tourId == null) {
                tourId = matchShortened(appCourses[i][1], latest);
            }
            if (tourId == null) {
                continue;
            }
            var item = [appCourses[i][0], appCourses[i][1], tourId];
            if (ownByTour.hasKey(tourId)) {
                duplicates.add(item);
            } else {
                ownByTour[tourId] = item[0];
                owned.add(item);
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
            } else if (own != null || isOnDevice(tour, lowerNames)) {
                onDevice++;
            } else {
                toAdd.add(tour);
            }
        }

        var toCheck = [];
        var toRemove = [];
        for (var i = 0; i < owned.size(); i++) {
            if (!latestIds.hasKey(owned[i][2])) {
                (keepOnlyLatest ? toRemove : toCheck).add(owned[i]);
            }
        }

        return { :toAdd => toAdd, :toUpdate => toUpdate, :toCheck => toCheck, :toRemove => toRemove,
                 :duplicates => duplicates, :onDevice => onDevice };
    }

    // Only a definite "not found" removes a course; any other answer keeps it.
    function isGone(responseCode) {
        return responseCode == 404;
    }

    // Komoot names its courses "<tour name> <tour id>"; long names are shortened ("<start>... <end of the id>").
    // Garmin Connect uses the bare tour name.
    function isOnDevice(tour, lowerNames) {
        var name = tour["name"].toLower();
        var idSuffix = " " + tour["id"];
        for (var i = 0; i < lowerNames.size(); i++) {
            if (lowerNames[i].equals(name) || endsWith(lowerNames[i], idSuffix) || matchesShortened(lowerNames[i], tour)) {
                return true;
            }
        }
        return false;
    }

    // The Komoot tour id at the end of a course name, or null. Komoot ids have 9+ digits; a shorter number is a cut-off id or
    // part of the name, and reading it as an id could remove the wrong course.
    function tourIdOf(courseName) {
        var start = digitsStart(courseName);
        var chars = courseName.toCharArray();
        if (chars.size() - start < 9 || start == 0 || chars[start - 1] != ' ') {
            return null;
        }
        return courseName.substring(start, chars.size());
    }

    // The id of the one latest tour a shortened course name belongs to, or null when none or several match.
    function matchShortened(courseName, latest) {
        var found = null;
        for (var i = 0; i < latest.size(); i++) {
            if (matchesShortened(courseName, latest[i])) {
                if (found != null) {
                    return null;
                }
                found = latest[i]["id"];
            }
        }
        return found;
    }

    // "Long walk proposal dagst... 2665" matches a tour whose name starts with "Long walk proposal dagst" and whose id ends
    // with 2665 (Komoot cuts the middle of "<name> <id>").
    function matchesShortened(courseName, tour) {
        var start = digitsStart(courseName);
        if (courseName.length() - start < 3 || start == 0) {
            return false;
        }
        var digits = courseName.substring(start, courseName.length());
        var prefix = withoutEllipsis(courseName.substring(0, start)).toLower();
        return prefix.length() >= 3 && endsWith(tour["id"], digits) && tour["name"].toLower().find(prefix) == 0;
    }

    function digitsStart(text) {
        var chars = text.toCharArray();
        var start = chars.size();
        while (start > 0 && chars[start - 1].toNumber() >= 48 && chars[start - 1].toNumber() <= 57) {
            start--;
        }
        return start;
    }

    // Drops trailing spaces, dots and "…".
    function withoutEllipsis(text) {
        var chars = text.toCharArray();
        var end = chars.size();
        while (end > 0 && (chars[end - 1] == ' ' || chars[end - 1] == '.' || chars[end - 1].toNumber() == 8230)) {
            end--;
        }
        return text.substring(0, end);
    }

    function endsWith(text, suffix) {
        var start = text.length() - suffix.length();
        return start >= 0 && text.substring(start, text.length()).equals(suffix);
    }
}
