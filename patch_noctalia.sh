#!/usr/bin/env bash

set -euo pipefail

# Patch Noctalia Shell QML system files.
# Called by arch_setup.sh after noctalia-shell-git is installed.
# Idempotent — each patch checks a guard before applying.
# Requires root (files live under /etc/xdg/quickshell/).

NOCTALIA_DIR="/etc/xdg/quickshell/noctalia-shell"

WORKSPACE_QML="$NOCTALIA_DIR/Modules/Bar/Widgets/Workspace.qml"
TOOLTIP_QML="$NOCTALIA_DIR/Modules/Tooltip/Tooltip.qml"
CALENDAR_QML="$NOCTALIA_DIR/Modules/Cards/CalendarMonthCard.qml"
WEATHER_QML="$NOCTALIA_DIR/Modules/Cards/WeatherCard.qml"
CLOCK_QML="$NOCTALIA_DIR/Modules/Panels/Clock/ClockPanel.qml"
NICON_QML="$NOCTALIA_DIR/Widgets/NIcon.qml"

# --- Workspace: textRatio 0.50 → 0.75 for Nerd Font glyphs ---

patch_workspace() {
    echo "  Workspace.qml: textRatio 0.50 → 0.75"
    if grep -q 'textRatio: 0\.75' "$WORKSPACE_QML"; then
        echo "    ✓ already applied"
        return
    fi
    if ! grep -q 'textRatio: 0\.50' "$WORKSPACE_QML"; then
        echo "    ⚠ WARNING: pattern 'textRatio: 0.50' not found — skipping"
        return
    fi
    sed -i 's/readonly property real textRatio: 0\.50/readonly property real textRatio: 0.75/' "$WORKSPACE_QML"
    echo "    ✓ applied"
}

# --- Tooltip: grid mode maxWidth, grid content width constraint, last-column fillWidth ---

patch_tooltip() {
    echo "  Tooltip.qml: grid mode sizing"

    # maxWidth: 340 → conditional on grid mode
    if grep -q 'isGridMode ? 560 : 340' "$TOOLTIP_QML"; then
        echo "    ✓ maxWidth already patched"
    elif grep -q 'property int maxWidth: 340' "$TOOLTIP_QML"; then
        sed -i 's/property int maxWidth: 340/property int maxWidth: isGridMode ? 560 : 340/' "$TOOLTIP_QML"
        echo "    ✓ maxWidth applied"
    else
        echo "    ⚠ WARNING: maxWidth pattern not found — skipping"
    fi

    # Grid content width constraint
    if grep -q 'width: parent.width - (root.padding \* 2)' "$TOOLTIP_QML"; then
        echo "    ✓ grid width constraint already applied"
    else
        sed -i '/id: gridContent/,/columnSpacing/ {
    /columns: root.columnCount/a\        width: parent.width - (root.padding * 2)
}' "$TOOLTIP_QML"
        if grep -q 'width: parent.width - (root.padding \* 2)' "$TOOLTIP_QML"; then
            echo "    ✓ grid width constraint applied"
        else
            echo "    ⚠ WARNING: grid width constraint insertion failed — skipping"
        fi
    fi

    # Last-column fillWidth
    if grep -q 'Layout.fillWidth: (index % root.columnCount)' "$TOOLTIP_QML"; then
        echo "    ✓ last-column fillWidth already applied"
    else
        sed -i '/Layout.preferredHeight: rowHeightMeasure.implicitHeight/a\            Layout.fillWidth: (index % root.columnCount) === (root.columnCount - 1)' "$TOOLTIP_QML"
        if grep -q 'Layout.fillWidth: (index % root.columnCount)' "$TOOLTIP_QML"; then
            echo "    ✓ last-column fillWidth applied"
        else
            echo "    ⚠ WARNING: last-column fillWidth insertion failed — skipping"
        fi
    fi
}

# --- Calendar: compact cells, dot cap, dot margin, date offset, today dot color, tooltip redesign, nav icons ---

patch_calendar() {
    echo "  CalendarMonthCard.qml: calendar patches"

    # Cap dots at 3
    if grep -q '\.slice(0, 3)' "$CALENDAR_QML"; then
        echo "    ✓ dot cap already applied"
    elif grep -q 'getEventsForDate(modelData\.year, modelData\.month, modelData\.day)$' "$CALENDAR_QML"; then
        sed -i 's/getEventsForDate(modelData\.year, modelData\.month, modelData\.day)$/getEventsForDate(modelData.year, modelData.month, modelData.day).slice(0, 3)/' "$CALENDAR_QML"
        echo "    ✓ dot cap applied"
    else
        echo "    ⚠ WARNING: dot cap pattern not found — skipping"
    fi

    # Dot margin: marginXS → fixed 2px
    if grep -q 'anchors.bottomMargin: 2$' "$CALENDAR_QML"; then
        echo "    ✓ dot margin already applied"
    elif grep -q 'anchors\.bottomMargin: Style\.marginXS' "$CALENDAR_QML"; then
        sed -i '/Event indicator dots/,/Repeater/ s/anchors\.bottomMargin: Style\.marginXS/anchors.bottomMargin: 2/' "$CALENDAR_QML"
        echo "    ✓ dot margin applied"
    else
        echo "    ⚠ WARNING: dot margin pattern not found — skipping"
    fi

    # Vertical center offset for date number
    if grep -q 'verticalCenterOffset' "$CALENDAR_QML"; then
        echo "    ✓ verticalCenterOffset already applied"
    else
        sed -i '/anchors.centerIn: parent/{n; s/text: modelData.day/anchors.verticalCenterOffset: -2\n                text: modelData.day/}' "$CALENDAR_QML"
        if grep -q 'verticalCenterOffset' "$CALENDAR_QML"; then
            echo "    ✓ verticalCenterOffset applied"
        else
            echo "    ⚠ WARNING: verticalCenterOffset insertion failed — skipping"
        fi
    fi

    # Today's event dot color: mOnSecondary → mPrimary
    if grep -q 'today-dot-fix' "$CALENDAR_QML"; then
        echo "    ✓ today dot color already applied"
    else
        python3 << 'DOT_PATCH_EOF'
import sys

path = "/etc/xdg/quickshell/noctalia-shell/Modules/Cards/CalendarMonthCard.qml"
with open(path) as f:
    src = f.read()

old = """      function getEventColor(event, isToday) {
        if (isMultiDayEvent(event)) {
          return isToday ? Color.mOnSecondary : Color.mTertiary;
        } else if (root.isAllDayEvent(event)) {
          return isToday ? Color.mOnSecondary : Color.mSecondary;
        } else {
          return isToday ? Color.mOnSecondary : Color.mPrimary;
        }
      }"""

new = """      function getEventColor(event, isToday) {
        // today-dot-fix
        if (isToday) return Color.mPrimary;
        if (isMultiDayEvent(event)) return Color.mTertiary;
        if (root.isAllDayEvent(event)) return Color.mSecondary;
        return Color.mPrimary;
      }"""

if old not in src:
    print("    ⚠ WARNING: getEventColor pattern not found — skipping", file=sys.stderr)
    sys.exit(0)

with open(path, "w") as f:
    f.write(src.replace(old, new, 1))
print("    ✓ today dot color applied")
DOT_PATCH_EOF
    fi

    # Tooltip redesign: sorted grid with time ranges
    # Check for marker (new script) or patched content (old script without marker)
    if grep -q 'sorted-tooltip-grid' "$CALENDAR_QML" || grep -q 'TooltipService\.show(parent, rows' "$CALENDAR_QML"; then
        echo "    ✓ tooltip redesign already applied"
    else
        python3 << 'TOOLTIP_PATCH_EOF'
import re, sys

path = "/etc/xdg/quickshell/noctalia-shell/Modules/Cards/CalendarMonthCard.qml"
with open(path) as f:
    src = f.read()

pattern = re.compile(
    r'(onEntered:\s*\{\s*\n)'
    r'\s*const events = parent\.parent\.parent\.parent\.getEventsForDate'
    r'.*?'
    r'TooltipService\.show\(parent,\s*summaries.*?\);'
    r'\s*\}',
    re.DOTALL
)

REPLACEMENT_BODY = '''\
                  // sorted-tooltip-grid
                  const events = parent.parent.parent.parent.getEventsForDate(modelData.year, modelData.month, modelData.day);
                  if (events.length > 0) {
                    // Sort: all-day first, then chronological by start time
                    const sorted = events.slice().sort((a, b) => {
                      const aAllDay = root.isAllDayEvent(a);
                      const bAllDay = root.isAllDayEvent(b);
                      if (aAllDay !== bAllDay) return aAllDay ? -1 : 1;
                      return a.start - b.start;
                    });
                    const timeFormat = Settings.data.location.use12hourFormat ? "hh:mm AP" : "HH:mm";
                    const rows = sorted.map(event => {
                      if (root.isAllDayEvent(event)) {
                        return ["ALL DAY", event.summary];
                      } else {
                        const start = new Date(event.start * 1000);
                        const end = new Date(event.end * 1000);
                        const startF = I18n.locale.toString(start, timeFormat);
                        const endF = I18n.locale.toString(end, timeFormat);
                        return [startF + "\u2013" + endF, event.summary];
                      }
                    });
                    TooltipService.show(parent, rows, "auto", Style.tooltipDelay, Settings.data.ui.fontFixed);
                  }'''

result, count = pattern.subn(lambda m: m.group(1) + REPLACEMENT_BODY, src)
if count == 0:
    print("    ⚠ WARNING: calendar tooltip pattern not found — skipping", file=sys.stderr)
    sys.exit(0)
with open(path, "w") as f:
    f.write(result)
print("    ✓ tooltip redesign applied")
TOOLTIP_PATCH_EOF
    fi

    # Compact cell size (0.9 → 0.8)
    if grep -q 'baseWidgetSize \* 0\.8' "$CALENDAR_QML"; then
        echo "    ✓ compact cells already applied"
    elif grep -q 'baseWidgetSize \* 0\.9' "$CALENDAR_QML"; then
        sed -i 's/baseWidgetSize \* 0\.9/baseWidgetSize * 0.8/g' "$CALENDAR_QML"
        echo "    ✓ compact cells applied"
    else
        echo "    ⚠ WARNING: compact cells pattern not found — skipping"
    fi

    # Nav icons: Tabler → Nerd Font glyphs
    if grep -q $'\uf104' "$CALENDAR_QML"; then
        echo "    ✓ nav icons already applied"
    else
        sed -i "s/icon: \"chevron-left\"/icon: \"$(printf '\uf104')\"/" "$CALENDAR_QML"
        sed -i 's/icon: "calendar"/icon: "󰃭"/' "$CALENDAR_QML"
        sed -i "s/icon: \"chevron-right\"/icon: \"$(printf '\uf105')\"/" "$CALENDAR_QML"
        echo "    ✓ nav icons applied"
    fi
}

# --- WeatherCard + ClockPanel: compact layout ---

patch_weather_and_clock() {
    echo "  WeatherCard.qml + ClockPanel.qml: compact layout"

    # WeatherCard: shrink main icon (XXXL*1.75 → XXL)
    # Note: centered header later overwrites this area, but apply for robustness
    if ! grep -q 'fontSizeXXXL \* 1\.75' "$WEATHER_QML"; then
        echo "    ✓ main icon already shrunk"
    else
        sed -i 's/fontSizeXXXL \* 1\.75/fontSizeXXL/' "$WEATHER_QML"
        echo "    ✓ main icon shrunk"
    fi

    # WeatherCard: shrink forecast icons (XXL*1.6 → XL)
    if ! grep -q 'fontSizeXXL \* 1\.6' "$WEATHER_QML"; then
        echo "    ✓ forecast icons already shrunk"
    else
        sed -i 's/fontSizeXXL \* 1\.6/fontSizeXL/' "$WEATHER_QML"
        echo "    ✓ forecast icons shrunk"
    fi

    # WeatherCard: reduce min height (100 → 70)
    if grep -q 'Math\.max(70 \* Style\.uiScaleRatio' "$WEATHER_QML"; then
        echo "    ✓ min height already reduced"
    elif grep -q 'Math\.max(100 \* Style\.uiScaleRatio' "$WEATHER_QML"; then
        sed -i 's/Math\.max(100 \* Style\.uiScaleRatio/Math.max(70 * Style.uiScaleRatio/' "$WEATHER_QML"
        echo "    ✓ min height reduced"
    else
        echo "    ⚠ WARNING: min height pattern not found — skipping"
    fi

    # WeatherCard: reduce margins (marginXL → marginM)
    if ! grep -q 'Style\.marginXL' "$WEATHER_QML"; then
        echo "    ✓ weather margins already reduced"
    else
        sed -i 's/Style\.marginXL/Style.marginM/g' "$WEATHER_QML"
        echo "    ✓ weather margins reduced"
    fi

    # WeatherCard: centered header layout
    if grep -q 'centered-weather-header' "$WEATHER_QML"; then
        echo "    ✓ centered header already applied"
    else
        python3 << 'WEATHER_PATCH_EOF'
import re, sys

path = "/etc/xdg/quickshell/noctalia-shell/Modules/Cards/WeatherCard.qml"
with open(path) as f:
    src = f.read()

pattern = re.compile(
    r'(    clip: true\n)\n'
    r'    RowLayout \{.*?'
    r'\n    \}\n'
    r'(\n    NDivider)',
    re.DOTALL
)

REPLACEMENT = (
    r"\1" + "\n"
    "    RowLayout {\n"
    "      // centered-weather-header\n"
    "      Layout.fillWidth: true\n"
    "      spacing: Style.marginS\n"
    "\n"
    "      Item { Layout.fillWidth: true }\n"
    "\n"
    "      NIcon {\n"
    "        Layout.alignment: Qt.AlignVCenter\n"
    '        icon: weatherReady ? LocationService.weatherSymbolFromCode(LocationService.data.weather.current_weather.weathercode, LocationService.data.weather.current_weather.is_day) : "weather-cloud-off"\n'
    "        pointSize: Style.fontSizeL\n"
    "        color: Color.mPrimary\n"
    "      }\n"
    "\n"
    "      NText {\n"
    "        text: {\n"
    '          const chunks = Settings.data.location.name.split(",");\n'
    "          return chunks[0];\n"
    "        }\n"
    "        pointSize: Style.fontSizeL\n"
    "        font.weight: Style.fontWeightBold\n"
    "        color: Color.mOnSurface\n"
    "        visible: showLocation && !Settings.data.location.hideWeatherCityName\n"
    "      }\n"
    "\n"
    "      NText {\n"
    "        visible: weatherReady\n"
    "        text: {\n"
    "          if (!weatherReady) {\n"
    '            return "";\n'
    "          }\n"
    "          var temp = LocationService.data.weather.current_weather.temperature;\n"
    '          var suffix = "C";\n'
    "          if (Settings.data.location.useFahrenheit) {\n"
    "            temp = LocationService.celsiusToFahrenheit(temp);\n"
    '            var suffix = "F";\n'
    "          }\n"
    "          temp = Math.round(temp);\n"
    "          return `${temp}\u00b0${suffix}`;\n"
    "        }\n"
    "        pointSize: Style.fontSizeM\n"
    "        font.weight: Style.fontWeightBold\n"
    "      }\n"
    "\n"
    "      NText {\n"
    '        text: weatherReady ? `(${LocationService.data.weather.timezone_abbreviation})` : ""\n'
    "        pointSize: Style.fontSizeXS\n"
    "        color: Color.mOnSurfaceVariant\n"
    "        visible: LocationService.data.weather && showLocation && !Settings.data.location.hideWeatherTimezone\n"
    "      }\n"
    "\n"
    "      Item { Layout.fillWidth: true }\n"
    "    }\n"
    + r"\2"
)

result, count = pattern.subn(REPLACEMENT, src)
if count == 0:
    print("    ⚠ WARNING: weather header pattern not found — skipping", file=sys.stderr)
    sys.exit(0)

with open(path, "w") as f:
    f.write(result)
print("    ✓ centered header applied")
WEATHER_PATCH_EOF
    fi

    # ClockPanel: tighten card spacing (marginL → marginS)
    if grep -q 'spacing: Style\.marginS' "$CLOCK_QML" && ! grep -q 'spacing: Style\.marginL' "$CLOCK_QML"; then
        echo "    ✓ clock spacing already tightened"
    elif grep -q 'spacing: Style\.marginL' "$CLOCK_QML"; then
        sed -i 's/spacing: Style\.marginL/spacing: Style.marginS/' "$CLOCK_QML"
        echo "    ✓ clock spacing tightened"
    else
        echo "    ⚠ WARNING: clock spacing pattern not found — skipping"
    fi

    # ClockPanel: reduce outer margin (marginL → marginM)
    if ! grep -q 'Style\.marginL' "$CLOCK_QML"; then
        echo "    ✓ clock margins already reduced"
    else
        sed -i 's/Style\.marginL/Style.marginM/g' "$CLOCK_QML"
        echo "    ✓ clock margins reduced"
    fi

    # ClockPanel: narrow panel width (440→410, 420→390)
    if grep -q '410 : 390' "$CLOCK_QML"; then
        echo "    ✓ clock panel width already narrowed"
    elif grep -q '440 : 420' "$CLOCK_QML"; then
        sed -i 's/440 : 420/410 : 390/' "$CLOCK_QML"
        echo "    ✓ clock panel width narrowed"
    else
        echo "    ⚠ WARNING: clock panel width pattern not found — skipping"
    fi

    # ClockPanel: show city name (showLocation: false → true)
    if grep -q 'showLocation: true' "$CLOCK_QML"; then
        echo "    ✓ showLocation already enabled"
    elif grep -q 'showLocation: false' "$CLOCK_QML"; then
        sed -i 's/showLocation: false/showLocation: true/' "$CLOCK_QML"
        echo "    ✓ showLocation enabled"
    else
        echo "    ⚠ WARNING: showLocation pattern not found — skipping"
    fi
}

# --- NIcon: raw Nerd Font glyph support ---

patch_nicon() {
    echo "  NIcon.qml: raw glyph support"
    if grep -q 'isRawGlyph' "$NICON_QML"; then
        echo "    ✓ already applied"
        return
    fi

    python3 << 'NICON_PATCH_EOF'
import sys

path = "/etc/xdg/quickshell/noctalia-shell/Widgets/NIcon.qml"
with open(path) as f:
    src = f.read()

# Add isRawGlyph property after applyUiScale
old_props = '  property bool applyUiScale: true'
new_props = '''  property bool applyUiScale: true

  readonly property bool isRawGlyph: icon !== undefined && icon !== "" && Icons.get(icon) === undefined'''

if old_props not in src:
    print("    ⚠ WARNING: NIcon.qml property block not found — skipping", file=sys.stderr)
    sys.exit(0)

src = src.replace(old_props, new_props, 1)

# Replace text binding to use raw glyph when icon is not in Tabler map
old_text = '''  text: {
    if ((icon === undefined) || (icon === "")) {
      return "";
    }
    if (Icons.get(icon) === undefined) {
      Logger.w("Icon", `"${icon}"`, "doesn't exist in the icons font");
      Logger.callStack();
      return Icons.get(Icons.defaultIcon);
    }
    return Icons.get(icon);
  }'''

new_text = '''  text: {
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
  }'''

if old_text not in src:
    print("    ⚠ WARNING: NIcon.qml text binding not found — skipping", file=sys.stderr)
    sys.exit(0)

src = src.replace(old_text, new_text, 1)

# Replace font.family to use fontFixed for raw glyphs
old_font = '  font.family: Icons.fontFamily'
new_font = '  font.family: root.isRawGlyph ? Settings.data.ui.fontFixed : Icons.fontFamily'

if old_font not in src:
    print("    ⚠ WARNING: NIcon.qml font.family not found — skipping", file=sys.stderr)
    sys.exit(0)

src = src.replace(old_font, new_font, 1)

with open(path, "w") as f:
    f.write(src)
print("    ✓ applied")
NICON_PATCH_EOF
}

# --- Main ---

main() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "Error: patch_noctalia.sh must be run as root"
        exit 1
    fi

    if [ ! -d "$NOCTALIA_DIR" ]; then
        echo "Error: Noctalia directory not found at $NOCTALIA_DIR"
        exit 1
    fi

    echo "Patching Noctalia Shell QML files..."
    patch_workspace
    patch_tooltip
    patch_calendar
    patch_weather_and_clock
    patch_nicon
    echo "Noctalia patches complete."
}

main "$@"
