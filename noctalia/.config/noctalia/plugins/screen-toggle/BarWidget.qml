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
  readonly property var scr: pluginApi ? pluginApi.mainInstance : null

  // Self-hide when no secondary screen available
  visible: scr ? scr.screenAvailable : false
  implicitWidth: visible ? pill.width : 0
  implicitHeight: visible ? pill.height : 0

  BarPill {
    id: pill

    screen: root.screen
    oppositeDirection: BarService.getPillDirection(root)
    customIconColor: Color.resolveColorKeyOptional(root.iconColorKey)
    customTextColor: Color.resolveColorKeyOptional(root.textColorKey)

    icon: {
      if (!root.scr || !root.scr.screenAvailable)
        return "device-laptop";
      return root.scr.screenEnabled ? "layout-rows" : "device-laptop";
    }

    text: ""

    autoHide: false
    forceOpen: false
    forceClose: true

    tooltipText: {
      if (!root.scr || !root.scr.screenAvailable) {
        if (root.pluginApi)
          return root.pluginApi.tr("tooltip.no-screen");
        return "No secondary screen detected";
      }
      if (root.scr.screenEnabled) {
        if (root.pluginApi)
          return root.pluginApi.tr("tooltip.screen-on");
        return "Secondary screen is on";
      }
      if (root.pluginApi)
        return root.pluginApi.tr("tooltip.screen-off");
      return "Secondary screen is off";
    }

    onClicked: {
      if (!root.scr || !root.pluginApi)
        return;
      if (!root.scr.screenAvailable) {
        ToastService.showNotice(root.pluginApi.tr("toast.title"), root.pluginApi.tr("toast.no-screen"), "device-laptop");
        return;
      }
      root.scr.toggle();
      var msg = root.scr.screenEnabled ? root.pluginApi.tr("toast.turned-off") : root.pluginApi.tr("toast.turned-on");
      ToastService.showNotice(root.pluginApi.tr("toast.title"), msg, root.scr.screenEnabled ? "device-laptop" : "layout-rows");
    }

    onRightClicked: {
      if (!root.scr || !root.pluginApi)
        return;
      var msg;
      if (!root.scr.screenAvailable) {
        msg = root.pluginApi.tr("toast.no-screen");
      } else {
        msg = root.scr.screenEnabled ? root.pluginApi.tr("tooltip.screen-on") : root.pluginApi.tr("tooltip.screen-off");
      }
      ToastService.showNotice(root.pluginApi.tr("toast.title"), msg, root.scr.screenEnabled ? "layout-rows" : "device-laptop");
    }
  }
}
