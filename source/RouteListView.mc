import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Progress of a sync or refresh: a status line, an optional summary, then one card per route.
// A card is { :name, :detail, :date, :state }; flows change :state and call refresh().
class RouteListView extends WatchUi.View {
    private const GAP = 6;

    private var _status as String;
    private var _summary as String? = null;
    private var _cards as Array<Dictionary> = [];
    private var _top as Number = 0;
    private var _visible as Number = 1;
    private var _follow as Boolean = true;
    private var _shown as Boolean = false;
    private var _light as Boolean = false;

    function initialize(status as String) {
        View.initialize();
        _status = status;
    }

    function onShow() as Void {
        _shown = true;
    }

    function onHide() as Void {
        _shown = false;
    }

    function isShown() as Boolean {
        return _shown;
    }

    function setStatus(status as String) as Void {
        _status = status;
        WatchUi.requestUpdate();
    }

    function setSummary(summary as String) as Void {
        _summary = summary;
        WatchUi.requestUpdate();
    }

    function addCard(card as Dictionary) as Dictionary {
        _cards.add(card);
        WatchUi.requestUpdate();
        return card;
    }

    function refresh() as Void {
        WatchUi.requestUpdate();
    }

    function scroll(cards as Number) as Void {
        _top += cards;
        if (_top > maxTop()) {
            _top = maxTop();
        }
        if (_top < 0) {
            _top = 0;
        }
        _follow = _top == maxTop();
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        // Round watches: keep everything inside the circle's wide middle band.
        var round = System.getDeviceSettings().screenShape == System.SCREEN_SHAPE_ROUND;
        var margin = round ? h / 7 : 4;
        var left = round ? w * 16 / 100 : 6;
        var width = w - 2 * left;
        var small = Graphics.FONT_XTINY;
        var smallH = dc.getFontHeight(small);

        // Follow the Edge theme (light unless night mode), like the system menus around this screen.
        _light = Theme.isLight();
        var background = _light ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        dc.setColor(background, background);
        dc.clear();

        var y = margin;
        dc.setColor(textColor(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, y, Graphics.FONT_SMALL, fit(_status, Graphics.FONT_SMALL, width, dc.getFontHeight(Graphics.FONT_SMALL)), Graphics.TEXT_JUSTIFY_CENTER);
        y += dc.getFontHeight(Graphics.FONT_SMALL);
        if (_summary != null) {
            dc.setColor(mutedColor(), Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, y, small, fit(_summary, small, width, smallH), Graphics.TEXT_JUSTIFY_CENTER);
            y += smallH;
        }
        y += GAP / 2;
        dc.setColor(_light ? 0xCCCCCC : 0x444444, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(left, y, left + width, y);
        y += GAP;

        var nameFont = Graphics.FONT_TINY;
        var nameH = dc.getFontHeight(nameFont);
        var cardH = nameH + 2 * smallH + 8;
        _visible = (h - margin - y) / (cardH + GAP);
        if (_visible < 1) {
            _visible = 1;
        }
        if (_follow || _top > maxTop()) {
            _top = maxTop();
        }
        for (var i = 0; i < _visible && _top + i < _cards.size(); i++) {
            drawCard(dc, _cards[_top + i], left, y, width, cardH);
            y += cardH + GAP;
        }
    }

    private function drawCard(dc as Dc, card as Dictionary, x as Number, y as Number, width as Number, height as Number) as Void {
        var nameFont = Graphics.FONT_TINY;
        var nameH = dc.getFontHeight(nameFont);
        var small = Graphics.FONT_XTINY;
        var smallH = dc.getFontHeight(small);
        var pad = 6;
        var inner = width - 2 * pad;
        dc.setColor(_light ? 0xEEEEEE : 0x222222, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, width, height, 8);
        dc.setColor(stateColor(card[:state]), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y + 4, 3, height - 8);

        var textY = y + 4;
        dc.setColor(textColor(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + pad, textY, nameFont, fit(card[:name], nameFont, inner, nameH), Graphics.TEXT_JUSTIFY_LEFT);
        textY += nameH;
        dc.setColor(mutedColor(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + pad, textY, small, fit(card[:detail], small, inner, smallH), Graphics.TEXT_JUSTIFY_LEFT);
        textY += smallH;
        dc.drawText(x + pad, textY, small, card[:date], Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(stateColor(card[:state]), Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + width - pad, textY, small, card[:state], Graphics.TEXT_JUSTIFY_RIGHT);
    }

    private function textColor() as Number {
        return _light ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE;
    }

    private function mutedColor() as Number {
        return _light ? 0x555555 : 0xBBBBBB;
    }

    // Darker shades on the light theme keep the state readable on a light card.
    private function stateColor(state) as Number {
        if ("Added".equals(state) || "Refreshed".equals(state)) {
            return _light ? 0x2E8B2E : 0x55DD55;
        }
        if ("Updated".equals(state)) {
            return _light ? 0x1E6FD9 : 0x55AAFF;
        }
        if ("Removed".equals(state)) {
            return _light ? 0xC62828 : 0xFF6666;
        }
        if ("Failed".equals(state) || "Too large".equals(state)) {
            return _light ? 0xC56A00 : 0xFFAA00;
        }
        if ("Downloading".equals(state)) {
            return _light ? 0x9A7D00 : 0xFFFF55;
        }
        return _light ? 0x777777 : 0x999999;
    }

    // Cuts text to one line of the given width, ending in an ellipsis when it is too long.
    private function fit(text, font, width as Number, height as Number) {
        if (text == null) {
            return "";
        }
        var fitted = Graphics.fitTextToArea(text, font, width, height, true);
        return fitted == null ? text : fitted;
    }

    private function maxTop() as Number {
        var top = _cards.size() - _visible;
        return top > 0 ? top : 0;
    }
}

class RouteListDelegate extends WatchUi.BehaviorDelegate {
    private var _view as RouteListView;

    function initialize(view as RouteListView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onNextPage() as Boolean {
        _view.scroll(1);
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.scroll(-1);
        return true;
    }
}
