import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Text {
  id: root

  property string icon: Icons.defaultIcon
  property real pointSize: Style.fontSizeL
  property bool applyUiScale: true

  readonly property bool isRawGlyph: icon !== undefined && icon !== "" && Icons.get(icon) === undefined

  visible: (icon !== undefined) && (icon !== "")
  text: {
    if ((icon === undefined) || (icon === "")) {
      return "";
    }
    if (Icons.get(icon) === undefined) {
      if (root.isRawGlyph) return icon;
      Logger.w("Icon", `"${icon}"`, "doesn't exist in the icons font");
      Logger.callStack();
      return Icons.get(Icons.defaultIcon);
    }
    return Icons.get(icon);
  }
  font.family: root.isRawGlyph ? Settings.data.ui.fontFixed : Icons.fontFamily
  font.pointSize: Math.max(1, applyUiScale ? root.pointSize * Style.uiScaleRatio : root.pointSize)
  color: Color.mOnSurface
  verticalAlignment: Text.AlignVCenter
  horizontalAlignment: Text.AlignHCenter
}
