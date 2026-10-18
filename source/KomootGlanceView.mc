import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// The glance: the app name and the result of the last sync, which Sync stores under "lastSync".
// fenix watches draw the launcher icon beside the glance on a dark background. Edges draw no icon and use a light
// background unless night mode is on, so on Edges the glance draws its own icon and picks the text colours.
(:glance)
class KomootGlanceView extends WatchUi.GlanceView {
    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        var settings = System.getDeviceSettings();
        var edge = settings.screenShape != System.SCREEN_SHAPE_ROUND;
        var light = edge && settings has :isNightModeEnabled && !settings.isNightModeEnabled;

        var x = 0;
        if (edge) {
            var size = dc.getHeight() * 7 / 10;
            drawIcon(dc, size / 2, dc.getHeight() / 2, size);
            x = size + size / 3;
        }

        var title = Graphics.FONT_TINY;
        var line = Graphics.FONT_XTINY;
        var titleH = dc.getFontHeight(title);
        var y = (dc.getHeight() - titleH - dc.getFontHeight(line)) / 2;
        dc.setColor(light ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, title, "Komoot Sync", Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(light ? 0x444444 : 0xBBBBBB, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + titleH, line, lastSyncText(), Graphics.TEXT_JUSTIFY_LEFT);
    }

    // The launcher icon, drawn: a green disc with a white route between a start and a finish dot.
    private function drawIcon(dc as Dc, cx as Number, cy as Number, size as Number) as Void {
        dc.setColor(0x4F8A2B, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, size / 2);
        var u = size / 10.0;
        var points = [[-2.6, 2.4], [-1.6, 0.4], [-0.3, 1.1], [0.5, -0.7], [1.7, -0.2], [2.6, -2.2]];
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(size / 12 > 2 ? size / 12 : 2);
        for (var i = 1; i < points.size(); i++) {
            dc.drawLine(cx + points[i - 1][0] * u, cy + points[i - 1][1] * u, cx + points[i][0] * u, cy + points[i][1] * u);
        }
        dc.fillCircle(cx + points[0][0] * u, cy + points[0][1] * u, size / 11 + 1);
        dc.fillCircle(cx + points[5][0] * u, cy + points[5][1] * u, size / 11 + 1);
        dc.setPenWidth(1);
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
