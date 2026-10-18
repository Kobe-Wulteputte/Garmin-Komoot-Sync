import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Runs a sync when opened and shows its log; follows the newest line until the user swipes back.
class SyncView extends WatchUi.View {
    private var _lines as Array<String> = [];
    private var _top as Number = 0;
    private var _visible as Number = 14;
    private var _rowCount as Number = 0;
    private var _follow as Boolean = true;
    private var _running as Boolean = false;
    private var _started as Boolean = false;

    function initialize() {
        View.initialize();
    }

    function onShow() as Void {
        if (!_started) {
            _started = true;
            startSync();
        }
    }

    function startSync() as Void {
        if (_running) {
            return;
        }
        _running = true;
        _lines = [];
        _top = 0;
        _follow = true;
        new Sync(method(:log), method(:onSyncDone)).start();
    }

    function onSyncDone() as Void {
        _running = false;
        // Edge 540/550 have no touchscreen; there the enter button triggers onSelect.
        log(System.getDeviceSettings().isTouchScreen ? "Tap to sync again" : "Press enter to sync again");
    }

    function log(line as String) as Void {
        System.println(line);
        _lines.add(line);
        WatchUi.requestUpdate();
    }

    function scroll(lines as Number) as Void {
        _top += lines;
        if (_top < 0) {
            _top = 0;
        }
        if (_top >= maxTop()) {
            _top = maxTop();
        }
        _follow = _top == maxTop();
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var font = Graphics.FONT_XTINY;
        var lineHeight = dc.getFontHeight(font);
        // Round watches (fenix): centred rows in the middle band. With a sixth of the height as margin,
        // the circle is about 74% of its width wide at the band edges, so wrap to 70%.
        var round = System.getDeviceSettings().screenShape == System.SCREEN_SHAPE_ROUND;
        var margin = round ? dc.getHeight() / 6 : 0;
        var width = round ? dc.getWidth() * 7 / 10 : dc.getWidth() - 4;
        var x = round ? dc.getWidth() / 2 : 2;
        var justify = round ? Graphics.TEXT_JUSTIFY_CENTER : Graphics.TEXT_JUSTIFY_LEFT;

        var rows = [];
        for (var i = 0; i < _lines.size(); i++) {
            addWrapped(rows, _lines[i], font, width, dc.getHeight());
        }
        _rowCount = rows.size();
        _visible = (dc.getHeight() - 2 * margin) / lineHeight;
        if (_follow || _top > maxTop()) {
            _top = maxTop();
        }
        for (var i = 0; i < _visible && _top + i < rows.size(); i++) {
            dc.drawText(x, margin + i * lineHeight, font, rows[_top + i], justify);
        }
    }

    // Splits a log line into rows that fit the given width.
    private function addWrapped(rows as Array<String>, line as String, font, width as Number, height as Number) as Void {
        var text = Graphics.fitTextToArea(line, font, width, height, false);
        if (text == null) {
            rows.add(line);
            return;
        }
        var newline = text.find("\n");
        while (newline != null) {
            rows.add(text.substring(0, newline));
            text = text.substring(newline + 1, text.length());
            newline = text.find("\n");
        }
        rows.add(text);
    }

    private function maxTop() as Number {
        var top = _rowCount - _visible;
        return top > 0 ? top : 0;
    }
}

class SyncDelegate extends WatchUi.BehaviorDelegate {
    private var _view as SyncView;

    function initialize(view as SyncView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() as Boolean {
        _view.startSync();
        return true;
    }

    function onTap(clickEvent as ClickEvent) as Boolean {
        _view.startSync();
        return true;
    }

    function onNextPage() as Boolean {
        _view.scroll(10);
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.scroll(-10);
        return true;
    }
}
