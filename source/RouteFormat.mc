import Toybox.Lang;

// Turns Komoot tour fields into the text shown on screen.
module RouteFormat {
    const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    const SPORTS = {
        "racebike" => "Road", "e_racebike" => "E-road", "mtb_easy" => "Gravel", "e_mtb_easy" => "E-gravel",
        "touringbicycle" => "Touring", "e_touringbicycle" => "E-touring", "mtb" => "MTB", "e_mtb" => "E-MTB",
        "mtb_advanced" => "Enduro", "e_mtb_advanced" => "E-enduro", "hike" => "Hike", "mountaineering" => "Mountaineering",
        "jogging" => "Run"
    };

    function distance(meters) {
        return meters == null ? "" : (meters / 1000.0).format("%.1f") + " km";
    }

    // "2026-10-17T13:52:07.000Z" -> "17 Oct 2026"
    function date(iso) {
        if (iso == null || iso.length() < 10) {
            return "";
        }
        var month = iso.substring(5, 7).toNumber();
        var day = iso.substring(8, 10).toNumber();
        if (month == null || day == null || month < 1 || month > 12) {
            return "";
        }
        return day + " " + MONTHS[month - 1] + " " + iso.substring(0, 4);
    }

    function sport(id) {
        var label = SPORTS[id];
        return label == null ? (id == null ? "" : id) : label;
    }

    // One line under the route name in the refresh list.
    function summary(tour) {
        return distance(tour["distance"]) + " · " + sport(tour["sport"]) + " · " + date(tour["date"]);
    }

    function card(tour, state) {
        return {
            :name => tour["name"],
            :detail => distance(tour["distance"]) + " · " + sport(tour["sport"]),
            :date => date(tour["date"]),
            :state => state
        };
    }
}
