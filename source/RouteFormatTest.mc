import Toybox.Lang;
import Toybox.Test;

(:test)
function formatsRouteDetails(logger as Logger) as Boolean {
    Test.assertEqual("42.3 km", RouteFormat.distance(42318.6));
    Test.assertEqual("0.8 km", RouteFormat.distance(812));
    Test.assertEqual("", RouteFormat.distance(null));
    Test.assertEqual("17 Oct 2026", RouteFormat.date("2026-10-17T13:52:07.000Z"));
    Test.assertEqual("", RouteFormat.date("bad"));
    Test.assertEqual("Gravel", RouteFormat.sport("mtb_easy"));
    Test.assertEqual("downhillbike", RouteFormat.sport("downhillbike"));
    Test.assertEqual("42.3 km · Road · 17 Oct 2026",
        RouteFormat.summary({ "distance" => 42318.6, "sport" => "racebike", "date" => "2026-10-17T13:52:07.000Z" }));
    return true;
}
