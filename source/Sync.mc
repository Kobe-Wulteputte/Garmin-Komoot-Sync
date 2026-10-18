import Toybox.Application;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.System;
import Toybox.Time;

// One sync run: load the latest planned tours of the chosen sports, remove own courses whose tour Komoot no longer has,
// install missing and changed latest tours. Each route gets a card on the view.
class Sync {
    // Komoot sports that can be planned (https://static.komoot.de/doc/external-api/v007/sports.html); each has a "sport_<id>" setting.
    private const SPORTS = ["racebike", "e_racebike", "mtb_easy", "e_mtb_easy", "touringbicycle", "e_touringbicycle",
        "mtb", "e_mtb", "mtb_advanced", "e_mtb_advanced", "hike", "mountaineering", "jogging"];

    private var _view;
    private var _komoot;
    private var _count = 30;
    private var _sportTypes = "";
    private var _loaded = 0;
    private var _startedAt = 0;
    private var _latest = [];
    private var _cards = {};
    private var _queue = [];
    private var _queueSize = 0;
    private var _before = {};
    private var _toCheck = [];
    private var _onDevice = 0;
    private var _added = 0;
    private var _updated = 0;
    private var _removed = 0;
    private var _failed = 0;
    private var _downloadLabel = "";

    function initialize(view, komoot) {
        _view = view;
        _komoot = komoot;
    }

    function start() {
        _count = countSetting();
        _sportTypes = sportTypesSetting();
        if (_sportTypes.length() == 0) {
            _view.setStatus("Turn on a sport in the settings");
            return;
        }
        _startedAt = System.getTimer();
        _view.setStatus("Logging in");
        _view.setSummary(Komoot.connectionText());
        _komoot.login(method(:onLogin));
    }

    function onLogin(ok, message) {
        if (!ok) {
            _view.setStatus(message);
            return;
        }
        _view.setStatus("Loading routes");
        new TourLoader(_komoot, _sportTypes, method(:onTour), method(:onSkip), method(:onLoaded)).load(_count);
    }

    // The loader delivers whole pages, so tours past the latest _count are ignored.
    function onTour(tour) {
        if (_loaded < _count) {
            _loaded++;
            _latest.add(tour);
            _cards[tour["id"]] = _view.addCard(RouteFormat.card(tour, "Checking"));
            _view.setStatus("Loading route " + _loaded + " of " + _count);
        }
    }

    function onSkip(position) {
        if (_loaded < _count) {
            _loaded++;
            _failed++;
            _view.addCard({ :name => "Route " + (position + 1), :detail => "Too much route data to load", :date => "", :state => "Too large" });
        }
    }

    function onLoaded(code, ended) {
        if (code != 200) {
            _view.setStatus("Loading failed (" + code + ")");
            _view.setSummary("Nothing was changed");
            return;
        }
        applyPlan();
    }

    function onCheck(code, data) {
        var item = _toCheck[0];
        _toCheck = _toCheck.slice(1, null);
        if (SyncPlan.isGone(code)) {
            removeOwn(item, "Deleted in Komoot");
        }
        checkNext();
    }

    // item is [course, name, tourId] of a course this app installed.
    private function removeOwn(item, reason) {
        var card = _view.addCard({ :name => item[1], :detail => reason, :date => "", :state => "Removed" });
        try {
            item[0].remove();
            _removed++;
        } catch (e) {
            _failed++;
            card[:state] = "Failed";
            _view.refresh();
        }
    }

    // An update downloads the new course first and only then removes the old one, so a failed download keeps the old route.
    function onFit(code, data) {
        var tour = _queue[0][0];
        var oldCourse = _queue[0][1];
        _queue = _queue.slice(1, null);
        var card = _cards[tour["id"]];
        if (code == Komoot.TIMED_OUT || code == Komoot.RECORDING) {
            // The other downloads would fail the same way.
            card[:state] = code == Komoot.RECORDING ? "Skipped" : "Timed out";
            for (var i = 0; i < _queue.size(); i++) {
                _cards[_queue[i][0]["id"]][:state] = "Skipped";
            }
            _view.setStatus(code == Komoot.RECORDING ? "No downloads during an activity" : "Download timed out");
            _view.setSummary("Try again after your activity");
            return;
        }
        if (code == 200 && data != null) {
            Installed.remember(tour, Installed.newCourse(data, _before));
            if (oldCourse == null) {
                _added++;
                card[:state] = "Added";
            } else {
                try {
                    oldCourse.remove();
                    _updated++;
                    card[:state] = "Updated";
                } catch (e) {
                    _failed++;
                    card[:state] = "Failed";
                }
            }
        } else {
            _failed++;
            card[:state] = "Failed";
        }
        _view.refresh();
        installNext();
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
        var owned = Installed.owned();
        it = PersistedContent.getAppCourses();
        course = it.next();
        while (course != null) {
            appCourses.add([course, course.getName(), Installed.tourIdFor(course, owned)]);
            course = it.next();
        }

        // A tour skipped as too large is still among the latest, so never prune on an incomplete list.
        var keepOnlyLatest = Properties.getValue("keepOnlyLatest") == true && _failed == 0;
        var plan = SyncPlan.plan(_latest, deviceNames, appCourses, Installed.changes(), keepOnlyLatest);
        _onDevice = plan[:onDevice];
        _queue = plan[:toUpdate];
        var toAdd = plan[:toAdd];
        for (var i = 0; i < toAdd.size(); i++) {
            _queue.add([toAdd[i], null]);
        }
        _queueSize = _queue.size();
        for (var i = 0; i < _latest.size(); i++) {
            _cards[_latest[i]["id"]][:state] = "On device";
        }
        for (var i = 0; i < _queue.size(); i++) {
            _cards[_queue[i][0]["id"]][:state] = "Waiting";
        }
        var duplicates = plan[:duplicates];
        for (var i = 0; i < duplicates.size(); i++) {
            removeOwn(duplicates[i], "Duplicate copy");
        }
        var toRemove = plan[:toRemove];
        for (var i = 0; i < toRemove.size(); i++) {
            removeOwn(toRemove[i], "Not in your latest " + _count);
        }
        _view.refresh();
        _toCheck = plan[:toCheck];
        checkNext();
    }

    private function checkNext() {
        if (_toCheck.size() == 0) {
            installNext();
            return;
        }
        _view.setStatus("Checking older routes");
        _komoot.checkTour(_toCheck[0][2], method(:onCheck));
    }

    private function installNext() {
        if (_queue.size() == 0) {
            var seconds = (System.getTimer() - _startedAt) / 1000;
            _view.setStatus((_failed > 0 ? "Done, " + _failed + " failed" : "Up to date") + " in " + seconds + " s");
            _view.setSummary(_added + " added · " + _updated + " updated · " + _removed + " removed · " + _onDevice + " kept");
            // Shown on the glance.
            Storage.setValue("lastSync", { "time" => Time.now().value(), "routes" => _added + _updated + _onDevice });
            return;
        }
        _downloadLabel = "Downloading " + (_queueSize - _queue.size() + 1) + " of " + _queueSize;
        _view.setStatus(_downloadLabel);
        _cards[_queue[0][0]["id"]][:state] = "Downloading";
        _view.refresh();
        _before = Installed.appCourseIds();
        _komoot.downloadFit(_queue[0][0]["id"], method(:onFit), method(:onProgress), false);
    }

    function onProgress(seconds, bytes) {
        _view.setStatus(Komoot.progressText(_downloadLabel, seconds, bytes));
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
        return count == null || count < 1 ? 30 : count;
    }
}
