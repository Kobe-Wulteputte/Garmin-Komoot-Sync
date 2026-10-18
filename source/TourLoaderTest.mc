import Toybox.Communications;
import Toybox.Lang;
import Toybox.Test;

// 12 tours; the page with positions 5-9 is too large as a whole, and position 7 is too large on its own.
// Like the real API it answers later: respondAll() delivers the queued answers one at a time.
(:test)
class FakeKomoot {
    var limits = [];
    private var _pending = null;

    function fetchPage(page, limit, sportTypes, callback) {
        limits.add(limit);
        _pending = [page, limit, callback];
    }

    function respondAll() {
        while (_pending != null) {
            var page = _pending[0];
            var limit = _pending[1];
            var callback = _pending[2];
            _pending = null;
            if ((limit == 5 && page == 1) || (limit == 1 && page == 7)) {
                callback.invoke(Communications.NETWORK_RESPONSE_TOO_LARGE, []);
            } else {
                var tours = [];
                for (var i = page * limit; i < page * limit + limit && i < 12; i++) {
                    tours.add({ "id" => i.toString() });
                }
                callback.invoke(200, tours);
            }
        }
    }
}

(:test)
class LoaderProbe {
    var ids = [];
    var skips = [];
    var done = null;

    function onTour(tour) {
        ids.add(tour["id"]);
    }

    function onSkip(position) {
        skips.add(position);
    }

    function onDone(code, ended) {
        done = [code, ended];
    }

    static function join(values) {
        var text = "";
        for (var i = 0; i < values.size(); i++) {
            text += (i > 0 ? "," : "") + values[i];
        }
        return text;
    }
}

(:test)
function loadsPagesAndFallsBackToSingleTours(logger as Logger) as Boolean {
    var komoot = new FakeKomoot();
    var probe = new LoaderProbe();
    new TourLoader(komoot, null, probe.method(:onTour), probe.method(:onSkip), probe.method(:onDone)).load(20);
    komoot.respondAll();
    Test.assertEqual("0,1,2,3,4,5,6,8,9,10,11", LoaderProbe.join(probe.ids));
    Test.assertEqual(1, probe.skips.size());
    Test.assertEqual(7, probe.skips[0]);
    Test.assertEqual(200, probe.done[0]);
    Test.assert(probe.done[1]);
    // pages: 0 (5), 1 (5, too large), then 5 singles, then page 2 (5, two tours: the end)
    Test.assertEqual("5,5,1,1,1,1,1,5", LoaderProbe.join(komoot.limits));
    return true;
}

(:test)
function stopsAfterTheRequestedPages(logger as Logger) as Boolean {
    var komoot = new FakeKomoot();
    var probe = new LoaderProbe();
    new TourLoader(komoot, null, probe.method(:onTour), probe.method(:onSkip), probe.method(:onDone)).load(3);
    komoot.respondAll();
    Test.assertEqual("0,1,2,3,4", LoaderProbe.join(probe.ids));
    Test.assert(!probe.done[1]);
    return true;
}
