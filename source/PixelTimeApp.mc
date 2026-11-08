import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

const STYLE_ROUND = 0;
const STYLE_ANGULAR = 1;

class PixelTimeApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var view = new PixelTimeView();
        return [view, new PixelTimeWatchDelegate(view)];
    }

    // Menu de ajustes en el propio reloj (mantener pulsado > Esfera > Personalizar).
    // Necesario porque las esferas instaladas a mano (.prg) no se pueden
    // configurar desde la app Garmin Connect.
    function getSettingsView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] or Null {
        var menu = new WatchUi.Menu2({:title => Rez.Strings.SettingsTitle});
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.StyleTitle, styleLabel(getStyle()), :style, null));
        menu.addItem(new WatchUi.ToggleMenuItem(Rez.Strings.DarkModeTitle, null, :darkMode, isDarkMode(), null));
        return [menu, new PixelTimeSettingsDelegate()];
    }

    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }
}

function isDarkMode() as Boolean {
    try {
        var v = Application.Properties.getValue("DarkMode");
        return (v instanceof Boolean) && (v as Boolean);
    } catch (e) {
        return false;
    }
}

function getStyle() as Number {
    try {
        var v = Application.Properties.getValue("Style");
        return ((v instanceof Number) && (v as Number) == STYLE_ANGULAR) ? STYLE_ANGULAR : STYLE_ROUND;
    } catch (e) {
        return STYLE_ROUND;
    }
}

function styleLabel(style as Number) as String {
    return WatchUi.loadResource(style == STYLE_ANGULAR ? Rez.Strings.StyleAngular : Rez.Strings.StyleRound) as String;
}

// Mantener pulsada la pantalla abre el calendario del mes. Con el calendario
// abierto: lado izquierdo = mes anterior, lado derecho = mes siguiente,
// centro = volver a la hora.
class PixelTimeWatchDelegate extends WatchUi.WatchFaceDelegate {

    private var _view as PixelTimeView;

    function initialize(view as PixelTimeView) {
        WatchFaceDelegate.initialize();
        _view = view;
    }

    function onPress(clickEvent as WatchUi.ClickEvent) as Boolean {
        if (!_view.showCalendar) {
            _view.showCalendar = true;
            _view.monthOffset = 0;
        } else {
            var x = clickEvent.getCoordinates()[0];
            var w = System.getDeviceSettings().screenWidth;
            if (x < w / 3) {
                _view.monthOffset -= 1;
            } else if (x > w * 2 / 3) {
                _view.monthOffset += 1;
            } else {
                _view.showCalendar = false;
                _view.monthOffset = 0;
            }
        }
        WatchUi.requestUpdate();
        return true;
    }
}

class PixelTimeSettingsDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :darkMode) {
            Application.Properties.setValue("DarkMode", (item as WatchUi.ToggleMenuItem).isEnabled());
        } else if (id == :style) {
            var next = getStyle() == STYLE_ANGULAR ? STYLE_ROUND : STYLE_ANGULAR;
            Application.Properties.setValue("Style", next);
            item.setSubLabel(styleLabel(next));
        }
        WatchUi.requestUpdate();
    }
}
