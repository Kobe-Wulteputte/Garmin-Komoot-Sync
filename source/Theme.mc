import Toybox.Lang;
import Toybox.System;

// Edges use a light theme unless night mode is on; fenix watches are always dark.
(:glance)
module Theme {
    function isLight() as Boolean {
        var settings = System.getDeviceSettings();
        return settings.screenShape != System.SCREEN_SHAPE_ROUND && settings has :isNightModeEnabled && !settings.isNightModeEnabled;
    }
}
