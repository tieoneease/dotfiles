import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

NIconButtonHot {
    property ShellScreen screen
    property var pluginApi

    readonly property var main: pluginApi ? pluginApi.mainInstance : null
    readonly property bool active: main ? main.inhibited : false

    hot: active
    icon: active ? "coffee" : "coffee-off"
    tooltipText: active ? "Sleep inhibited (screen can still turn off)" : "Sleep allowed"

    onClicked: {
        if (!main || !pluginApi)
            return;
        // Capture the state we're switching TO before toggle
        // (main.inhibited updates async via Process.onStarted)
        var willInhibit = !main.inhibited;
        main.toggle();
        var msg = willInhibit ? "Sleep inhibited" : "Sleep allowed";
        ToastService.showNotice("Sleep Inhibitor", msg, willInhibit ? "coffee" : "coffee-off");
    }
}
