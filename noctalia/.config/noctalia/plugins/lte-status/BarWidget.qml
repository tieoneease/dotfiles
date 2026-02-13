import QtQuick
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property ShellScreen screen
  property var pluginApi

  // Widget properties passed from Bar.qml for per-instance settings
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  property var widgetMetadata: BarWidgetRegistry.widgetMetadata[widgetId]
  readonly property string screenName: screen ? screen.name : ""
  property var widgetSettings: {
    if (section && sectionWidgetIndex >= 0 && screenName) {
      var widgets = Settings.getBarWidgetsForScreen(screenName)[section];
      if (widgets && sectionWidgetIndex < widgets.length) {
        return widgets[sectionWidgetIndex];
      }
    }
    return {};
  }

  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"
  readonly property string displayMode: widgetSettings.displayMode !== undefined ? widgetSettings.displayMode : (widgetMetadata ? widgetMetadata.displayMode : "alwaysShow")
  readonly property string iconColorKey: widgetSettings.iconColor !== undefined ? widgetSettings.iconColor : (widgetMetadata ? widgetMetadata.iconColor : "")
  readonly property string textColorKey: widgetSettings.textColor !== undefined ? widgetSettings.textColor : (widgetMetadata ? widgetMetadata.textColor : "")

  // Get main instance from pluginApi
  readonly property var lte: pluginApi ? pluginApi.mainInstance : null

  implicitWidth: pill.width
  implicitHeight: pill.height

  BarPill {
    id: pill

    screen: root.screen
    oppositeDirection: BarService.getPillDirection(root)
    customIconColor: Color.resolveColorKeyOptional(root.iconColorKey)
    customTextColor: Color.resolveColorKeyOptional(root.textColorKey)

    icon: {
      if (!root.lte || !root.lte.modemAvailable)
        return "antenna-bars-off";
      return root.lte.signalIcon();
    }

    text: {
      if (!root.lte || !root.lte.modemAvailable)
        return "";
      return root.lte.techLabel();
    }

    autoHide: false
    forceOpen: !isBarVertical && root.displayMode === "alwaysShow"
    forceClose: isBarVertical || root.displayMode === "alwaysHide" || text === ""

    tooltipText: {
      if (!root.lte || !root.lte.modemAvailable) {
        if (root.pluginApi)
          return root.pluginApi.tr("tooltip.no-modem");
        return "No modem detected";
      }
      if (root.lte.modemState !== "connected" && root.lte.modemState !== "registered") {
        if (root.pluginApi)
          return root.pluginApi.tr("tooltip.disconnected");
        return "Cellular disconnected";
      }
      var op = root.lte.operatorName || "";
      var tech = root.lte.techLabel();
      var sig = root.lte.signalQuality;
      var parts = [];
      if (op) parts.push(op);
      if (tech) parts.push(tech);
      parts.push(sig + "%");
      return parts.join(" \u2014 ");
    }

    onClicked: {
      if (!root.lte || !root.pluginApi)
        return;
      var msg;
      if (!root.lte.modemAvailable) {
        msg = root.pluginApi.tr("toast.no-modem");
      } else if (root.lte.modemState !== "connected" && root.lte.modemState !== "registered") {
        msg = root.pluginApi.tr("toast.disconnected");
      } else {
        msg = root.pluginApi.tr("toast.details", {
          "operator": root.lte.operatorName,
          "tech": root.lte.techLabel(),
          "signal": root.lte.signalQuality
        });
      }
      ToastService.showNotice(root.pluginApi.tr("toast.title"), msg, root.lte.signalIcon());
    }

    onRightClicked: {
      if (!root.lte || !root.pluginApi)
        return;
      var msg;
      if (!root.lte.modemAvailable) {
        msg = root.pluginApi.tr("toast.no-modem");
      } else {
        msg = root.pluginApi.tr("toast.details", {
          "operator": root.lte.operatorName,
          "tech": root.lte.techLabel(),
          "signal": root.lte.signalQuality
        });
      }
      ToastService.showNotice(root.pluginApi.tr("toast.title"), msg, root.lte.signalIcon());
    }
  }
}
