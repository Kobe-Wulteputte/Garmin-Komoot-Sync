import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// The glance: the app name and the result of the last sync, which Sync stores under "lastSync".
// The system draws the launcher icon in its own slot left of the glance. x40 Edge firmware leaves that slot blank for
// Connect IQ apps (also the Komoot app); drawing an icon here would only push the text out of line with the other glances.
(:glance)
class KomootGlanceView extends WatchUi.GlanceView {
    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        var light = Theme.isLight();

        var title = Graphics.FONT_TINY;
        var line = Graphics.FONT_XTINY;
        var titleH = dc.getFontHeight(title);
        var y = (dc.getHeight() - titleH - dc.getFontHeight(line)) / 2;
        dc.setColor(light ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, y, title, "Komoot Sync", Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(light ? 0x444444 : 0xBBBBBB, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, y + titleH, line, lastSyncText(), Graphics.TEXT_JUSTIFY_LEFT);
    }

    private function lastSyncText() as String {
        var last = Storage.getValue("lastSync");
        if (!(last instanceof Dictionary) || last["time"] == null) {
            return "Not synced yet";
        }
        var info = Gregorian.info(new Time.Moment(last["time"]), Time.FORMAT_MEDIUM);
        var when = info.day + " " + info.month + " " + info.hour.format("%02d") + ":" + info.min.format("%02d");
        return when + " · " + last["routes"] + " routes";
    }
}
