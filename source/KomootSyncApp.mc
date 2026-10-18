import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// The app class is also loaded for the glance, so it must not create anything outside the (:glance) code at load time.
(:glance)
class KomootSyncApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var menu = new WatchUi.Menu2({ :title => "Komoot Sync" });
        menu.addItem(new WatchUi.MenuItem("Sync now", "Get your latest routes", :sync, null));
        menu.addItem(new WatchUi.MenuItem("Refresh a route", "Download one route again", :refresh, null));
        return [menu, new MainMenuDelegate(new Komoot())];
    }

    function getGlanceView() as [GlanceView] or [GlanceView, GlanceViewDelegate] or Null {
        return [new KomootGlanceView()];
    }
}
