import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class KomootSyncApp extends Application.AppBase {
    var komoot = new Komoot();

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var menu = new WatchUi.Menu2({ :title => "Komoot Sync" });
        menu.addItem(new WatchUi.MenuItem("Sync now", "Get your latest routes", :sync, null));
        menu.addItem(new WatchUi.MenuItem("Refresh a route", "Download one route again", :refresh, null));
        return [menu, new MainMenuDelegate(komoot)];
    }
}
