import Toybox.Lang;
import Toybox.WatchUi;

class MainMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _komoot;

    function initialize(komoot) {
        Menu2InputDelegate.initialize();
        _komoot = komoot;
    }

    function onSelect(item as MenuItem) as Void {
        if (item.getId() == :sync) {
            var view = new RouteListView("Starting");
            WatchUi.pushView(view, new RouteListDelegate(view), WatchUi.SLIDE_LEFT);
            new Sync(view, _komoot).start();
        } else {
            new RoutePicker(_komoot).open();
        }
    }
}

// Lists every planned route of every sport, newest first, PAGE at a time with a "Load more" entry.
class RoutePicker {
    private const PAGE = 10;

    private var _komoot;
    private var _tours = [];
    private var _next = 0;
    private var _target = 0;
    private var _end = false;
    private var _focus = 0;
    private var _loading;

    function initialize(komoot) {
        _komoot = komoot;
    }

    function open() {
        _loading = new RouteListView("Loading routes");
        WatchUi.pushView(_loading, new RouteListDelegate(_loading), WatchUi.SLIDE_LEFT);
        _komoot.login(method(:onLogin));
    }

    function onLogin(ok, message) {
        if (!ok) {
            _loading.setStatus(message);
            return;
        }
        loadPage();
    }

    function onTour(code, tour) {
        if (Komoot.isTooLarge(code)) {
            _next++;
        } else if (code != 200) {
            _loading.setStatus("Loading failed (" + code + ")");
            return;
        } else if (tour == null) {
            _end = true;
            showMenu();
            return;
        } else {
            _tours.add(tour);
            _next++;
        }
        if (_next < _target) {
            fetchNext();
        } else {
            showMenu();
        }
    }

    function onPick(id) {
        if (id == :more) {
            _focus = _tours.size();
            _loading = new RouteListView("Loading routes");
            WatchUi.switchToView(_loading, new RouteListDelegate(_loading), WatchUi.SLIDE_IMMEDIATE);
            loadPage();
        } else if (id instanceof Number) {
            var view = new RouteListView("Refreshing");
            WatchUi.pushView(view, new RouteListDelegate(view), WatchUi.SLIDE_LEFT);
            new Refresh(view, _komoot, _tours[id]).start();
        }
    }

    private function loadPage() {
        _target = _next + PAGE;
        fetchNext();
    }

    private function fetchNext() {
        _loading.setStatus("Loading route " + (_next + 1));
        _komoot.fetchTour(_next, null, method(:onTour));
    }

    private function showMenu() {
        // The user may have left the loading screen; then switching views would replace another screen.
        if (!_loading.isShown()) {
            return;
        }
        var menu = new WatchUi.Menu2({ :title => "Refresh a route", :focus => _focus });
        for (var i = 0; i < _tours.size(); i++) {
            menu.addItem(new WatchUi.MenuItem(_tours[i]["name"], RouteFormat.summary(_tours[i]), i, null));
        }
        if (!_end) {
            menu.addItem(new WatchUi.MenuItem("Load more", "Next " + PAGE + " routes", :more, null));
        } else if (_tours.size() == 0) {
            menu.addItem(new WatchUi.MenuItem("No planned routes", null, :none, null));
        }
        WatchUi.switchToView(menu, new RoutePickerDelegate(self), WatchUi.SLIDE_IMMEDIATE);
    }
}

class RoutePickerDelegate extends WatchUi.Menu2InputDelegate {
    private var _picker;

    function initialize(picker) {
        Menu2InputDelegate.initialize();
        _picker = picker;
    }

    function onSelect(item as MenuItem) as Void {
        _picker.onPick(item.getId());
    }
}
