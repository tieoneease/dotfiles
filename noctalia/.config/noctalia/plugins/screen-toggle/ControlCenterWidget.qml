import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

NIconButtonHot {
  property ShellScreen screen
  property var pluginApi

  readonly property var scr: pluginApi ? pluginApi.mainInstance : null

  // Self-hide when no secondary screen available
  visible: scr ? scr.screenAvailable : false

  hot: scr ? scr.screenEnabled : false

  icon: {
    if (!scr || !scr.screenAvailable)
      return "device-laptop";
    return scr.screenEnabled ? "layout-rows" : "device-laptop";
  }

  tooltipText: {
    if (!scr || !scr.screenAvailable) {
      if (pluginApi)
        return pluginApi.tr("tooltip.no-screen");
      return "No secondary screen detected";
    }
    if (scr.screenEnabled) {
      if (pluginApi)
        return pluginApi.tr("tooltip.screen-on");
      return "Secondary screen is on";
    }
    if (pluginApi)
      return pluginApi.tr("tooltip.screen-off");
    return "Secondary screen is off";
  }

  onClicked: {
    if (!scr || !pluginApi)
      return;
    if (!scr.screenAvailable) {
      ToastService.showNotice(pluginApi.tr("toast.title"), pluginApi.tr("toast.no-screen"), "device-laptop");
      return;
    }
    scr.toggle();
    var msg = scr.screenEnabled ? pluginApi.tr("toast.turned-off") : pluginApi.tr("toast.turned-on");
    ToastService.showNotice(pluginApi.tr("toast.title"), msg, scr.screenEnabled ? "device-laptop" : "layout-rows");
  }
}
