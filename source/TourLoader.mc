import Toybox.Lang;

// Loads planned tours newest first, PAGE per request. Komoot sends 5-19 KB of JSON per tour (older, hand-planned tours
// carry long `path` and `segments`), and about 35 KB is the most the device accepts, so pages of 5 failed for all but
// the newest tours. A page that is still too large (-402/-403) is loaded one tour per request.
// Callbacks: onTour(tour), onSkip(position) for a single tour too large to load, onDone(code, ended).
class TourLoader {
    private const PAGE = 2;

    private var _komoot;
    private var _sportTypes;
    private var _onTour;
    private var _onSkip;
    private var _onDone;
    private var _next = 0;
    private var _target = 0;
    private var _singleUntil = 0;

    function initialize(komoot, sportTypes, onTour, onSkip, onDone) {
        _komoot = komoot;
        _sportTypes = sportTypes;
        _onTour = onTour;
        _onSkip = onSkip;
        _onDone = onDone;
    }

    // Loads at least `count` more tours, continuing where the previous call stopped. Whole pages are delivered,
    // so a few more than `count` may arrive.
    function load(count) {
        _target = _next + count;
        step();
    }

    function onPage(code, tours) {
        if (_next < _singleUntil) {
            if (Komoot.isTooLarge(code)) {
                _onSkip.invoke(_next);
                _next++;
                step();
                return;
            }
        } else if (Komoot.isTooLarge(code)) {
            _singleUntil = _next + PAGE;
            step();
            return;
        }
        if (code != 200) {
            _onDone.invoke(code, false);
            return;
        }
        for (var i = 0; i < tours.size(); i++) {
            _onTour.invoke(tours[i]);
        }
        var expected = _next < _singleUntil ? 1 : PAGE;
        _next += expected;
        if (tours.size() < expected) {
            _onDone.invoke(200, true);
        } else {
            step();
        }
    }

    private function step() {
        if (_next >= _target && _next >= _singleUntil) {
            _onDone.invoke(200, false);
        } else if (_next < _singleUntil) {
            _komoot.fetchPage(_next, 1, _sportTypes, method(:onPage));
        } else {
            _komoot.fetchPage(_next / PAGE, PAGE, _sportTypes, method(:onPage));
        }
    }
}
