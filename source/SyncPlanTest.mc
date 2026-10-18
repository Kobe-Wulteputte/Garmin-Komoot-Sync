import Toybox.Lang;
import Toybox.Test;

(:test)
function addsOnlyToursMissingFromTheDevice(logger as Logger) as Boolean {
    var latest = [
        { "id" => "111", "name" => "Komoot App Tour" },
        { "id" => "222", "name" => "Garmin Connect Tour" },
        { "id" => "333", "name" => "New Tour" },
        { "id" => "444", "name" => "A Very Long Tour Name That Komoot Shortens" }
    ];
    var deviceNames = ["Komoot App Tour 111", "garmin connect tour", "A Very Long Tour ... 444", "New Tour Extended"];
    var result = SyncPlan.plan(latest, deviceNames, [], {});
    Test.assertEqual(1, result[:toAdd].size());
    Test.assertEqual("333", result[:toAdd][0]["id"]);
    Test.assertEqual(3, result[:onDevice]);
    return true;
}

(:test)
function checksOnlyOwnCoursesOutsideTheLatest(logger as Logger) as Boolean {
    var latest = [{ "id" => "111111", "name" => "Latest" }];
    var appCourses = [["latest", "Latest 111111"], ["older", "Older 999999"], ["noId", "No id here"]];
    var result = SyncPlan.plan(latest, ["Latest 111111", "Older 999999", "No id here"], appCourses, {});
    Test.assertEqual(1, result[:toCheck].size());
    Test.assertEqual("older", result[:toCheck][0][0]);
    Test.assertEqual("999999", result[:toCheck][0][2]);
    Test.assert(SyncPlan.isGone(404));
    Test.assert(!SyncPlan.isGone(-402));
    return true;
}

(:test)
function updatesOwnCoursesWhoseTourChanged(logger as Logger) as Boolean {
    var latest = [
        { "id" => "111111", "name" => "Same", "changed" => "2026-10-01" },
        { "id" => "222222", "name" => "Edited", "changed" => "2026-10-18" },
        { "id" => "333333", "name" => "Installed before changes were stored", "changed" => "2026-10-01" },
        { "id" => "444444", "name" => "Garmin Connect copy", "changed" => "2026-10-18" }
    ];
    var appCourses = [["same", "Same 111111"], ["edited", "Edited 222222"], ["old", "Installed before ... 333333"]];
    var deviceNames = ["Same 111111", "Edited 222222", "Installed before ... 333333", "Garmin Connect copy"];
    var installed = { "111111" => "2026-10-01", "222222" => "2026-10-01" };
    var result = SyncPlan.plan(latest, deviceNames, appCourses, installed);
    Test.assertEqual(2, result[:toUpdate].size());
    Test.assertEqual("edited", result[:toUpdate][0][1]);
    Test.assertEqual("old", result[:toUpdate][1][1]);
    Test.assertEqual(2, result[:onDevice]);
    Test.assertEqual(0, result[:toAdd].size());
    return true;
}

(:test)
function readsTheTourIdAtTheEndOfACourseName(logger as Logger) as Boolean {
    Test.assertEqual("3100000002", SyncPlan.tourIdOf("To Vierzele Village ... 3100000002"));
    Test.assert(SyncPlan.tourIdOf("New 1h route") == null);
    Test.assert(SyncPlan.tourIdOf("1234567890") == null);
    Test.assert(SyncPlan.tourIdOf("Gourmand Route 2") == null);
    return true;
}
