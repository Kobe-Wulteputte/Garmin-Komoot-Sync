import Toybox.Lang;
import Toybox.PersistedContent;

// Downloads one route again. The old copy is removed only after the download succeeded, and only if this app installed it;
// a copy from Garmin Connect or the Komoot app cannot be removed and stays on the device.
class Refresh {
    private var _view;
    private var _komoot;
    private var _tour;
    private var _card;
    private var _ownCourse = null;
    private var _otherCopy = false;
    private var _before = {};

    function initialize(view, komoot, tour) {
        _view = view;
        _komoot = komoot;
        _tour = tour;
    }

    function start() {
        _card = _view.addCard(RouteFormat.card(_tour, "Waiting"));
        _view.setStatus("Logging in");
        _view.setSummary(Komoot.connectionText());
        _komoot.login(method(:onLogin));
    }

    function onLogin(ok, message) {
        if (!ok) {
            _view.setStatus(message);
            return;
        }
        var owned = Installed.owned();
        var it = PersistedContent.getAppCourses();
        var course = it.next();
        while (course != null) {
            if (_tour["id"].equals(Installed.tourIdFor(course, owned))) {
                _ownCourse = course;
            }
            course = it.next();
        }
        if (_ownCourse == null) {
            var names = [];
            it = PersistedContent.getCourses();
            course = it.next();
            while (course != null) {
                names.add(course.getName().toLower());
                course = it.next();
            }
            _otherCopy = SyncPlan.isOnDevice(_tour, names);
        }
        _view.setStatus("Downloading");
        _card[:state] = "Downloading";
        _view.refresh();
        _before = Installed.appCourseIds();
        _komoot.downloadFit(_tour["id"], method(:onFit), method(:onProgress), true);
    }

    function onProgress(seconds, bytes) {
        _view.setStatus(Komoot.progressText("Downloading", seconds, bytes));
    }

    function onFit(code, data) {
        if (code == Komoot.TIMED_OUT || code == Komoot.RECORDING) {
            _card[:state] = code == Komoot.RECORDING ? "Skipped" : "Timed out";
            _view.setStatus(code == Komoot.RECORDING ? "No downloads during an activity" : "Download timed out");
            _view.setSummary("Try again after your activity");
            return;
        }
        if (code != 200 || data == null) {
            _card[:state] = "Failed";
            _view.setStatus("Download failed (" + code + ")");
            _view.setSummary("The old copy was kept");
            return;
        }
        Installed.remember(_tour, Installed.newCourse(data, _before));
        _card[:state] = "Refreshed";
        _view.setStatus("Refreshed");
        if (_ownCourse != null) {
            try {
                _ownCourse.remove();
                _view.setSummary("Old copy replaced");
            } catch (e) {
                _view.setSummary("Old copy could not be removed");
            }
        } else if (_otherCopy) {
            _view.setSummary("Delete the other old copy by hand");
        } else {
            _view.setSummary("Was not on the device yet");
        }
    }
}
