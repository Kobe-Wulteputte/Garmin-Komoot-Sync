import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Runs a sync when opened and shows its log; follows the newest line until the user swipes back.
class SyncView extends WatchUi.View {
    private var _lines as Array<String> = [];
    private var _top as Number = 0;
    private var _visible as Number = 14;
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
        log("Tap to sync again");
    }

    function log(line as String) as Void {
        System.println(line);
        _lines.add(line);
        if (_follow) {
            _top = maxTop();
        }
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
        var lineHeight = dc.getFontHeight(Graphics.FONT_XTINY);
        _visible = dc.getHeight() / lineHeight;
        for (var i = 0; i < _visible && _top + i < _lines.size(); i++) {
            dc.drawText(2, i * lineHeight, Graphics.FONT_XTINY, _lines[_top + i], Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    private function maxTop() as Number {
        var top = _lines.size() - _visible;
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
