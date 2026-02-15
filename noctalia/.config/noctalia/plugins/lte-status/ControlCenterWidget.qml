import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

NIconButtonHot {
  property ShellScreen screen
  property var pluginApi

  readonly property var lte: pluginApi ? pluginApi.mainInstance : null

  visible: lte ? lte.modemAvailable : false

  hot: lte ? (lte.modemAvailable && (lte.modemState === "connected" || lte.modemState === "registered")) : false

  icon: {
    if (!lte || !lte.modemAvailable)
      return "antenna-bars-off";
    return lte.signalIcon();
  }

  tooltipText: {
    if (!lte || !lte.modemAvailable) {
      if (pluginApi)
        return pluginApi.tr("tooltip.no-modem");
      return "No modem detected";
    }
    if (lte.modemState !== "connected" && lte.modemState !== "registered") {
      if (pluginApi)
        return pluginApi.tr("tooltip.disconnected");
      return "Cellular disconnected";
    }
    var op = lte.operatorName || "";
    var tech = lte.techLabel();
    var sig = lte.signalQuality;
    var parts = [];
    if (op) parts.push(op);
    if (tech) parts.push(tech);
    parts.push(sig + "%");
    return parts.join(" \u2014 ");
  }

  onClicked: {
    if (!lte || !pluginApi)
      return;
    var msg;
    if (!lte.modemAvailable) {
      msg = pluginApi.tr("toast.no-modem");
    } else if (lte.modemState !== "connected" && lte.modemState !== "registered") {
      msg = pluginApi.tr("toast.disconnected");
    } else {
      msg = pluginApi.tr("toast.details", {
        "operator": lte.operatorName,
        "tech": lte.techLabel(),
        "signal": lte.signalQuality
      });
    }
    ToastService.showNotice(pluginApi.tr("toast.title"), msg, lte ? lte.signalIcon() : "antenna-bars-off");
  }
}
