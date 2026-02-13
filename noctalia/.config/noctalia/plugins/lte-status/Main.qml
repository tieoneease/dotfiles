import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var pluginApi

  // Reactive state properties
  property string modemState: ""
  property int signalQuality: 0
  property string accessTech: ""
  property string operatorName: ""
  property bool modemAvailable: false
  property string modemIndex: ""

  visible: false

  // Poll interval from plugin settings, default 10s
  readonly property int pollingInterval: {
    if (pluginApi && pluginApi.pluginSettings && pluginApi.pluginSettings.pollingInterval)
      return pluginApi.pluginSettings.pollingInterval;
    return 10000;
  }

  // --- Signal icon helper ---
  function signalIcon() {
    if (modemState !== "connected" && modemState !== "registered")
      return "antenna-bars-off";
    if (signalQuality >= 80) return "antenna-bars-5";
    if (signalQuality >= 60) return "antenna-bars-4";
    if (signalQuality >= 40) return "antenna-bars-3";
    if (signalQuality >= 20) return "antenna-bars-2";
    return "antenna-bars-1";
  }

  // --- Tech label helper ---
  function techLabel() {
    var t = accessTech.toLowerCase();
    if (t === "lte") return "LTE";
    if (t === "umts") return "3G";
    if (t === "hspa") return "H+";
    if (t === "hsdpa" || t === "hsupa") return "H";
    if (t === "edge") return "E";
    if (t === "gprs") return "G";
    if (t === "5gnr") return "5G";
    if (t === "gsm") return "2G";
    if (t === "") return "";
    return accessTech.toUpperCase();
  }

  // --- Step 1: Discover modem path ---
  Process {
    id: listProcess
    command: ["mmcli", "-L", "-J"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var result = JSON.parse(text);
          var modems = result["modem-list"];
          if (modems && modems.length > 0) {
            // Extract modem index from path like "/org/freedesktop/ModemManager1/Modem/1"
            var parts = modems[0].split("/");
            root.modemIndex = parts[parts.length - 1];
            statusProcess.command = ["mmcli", "-m", root.modemIndex, "-J"];
            statusProcess.running = true;
          } else {
            root.modemAvailable = false;
          }
        } catch (e) {
          root.modemAvailable = false;
        }
      }
    }
  }

  // --- Step 2: Poll modem status ---
  Process {
    id: statusProcess
    command: ["mmcli", "-m", "0", "-J"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var result = JSON.parse(text);
          var modem = result.modem;
          root.modemState = modem.generic.state || "";
          root.signalQuality = modem.generic["signal-quality"].value || 0;
          var techs = modem.generic["access-technologies"];
          root.accessTech = (techs && techs.length > 0) ? techs[0] : "";
          root.operatorName = modem["3gpp"]["operator-name"] || "";
          root.modemAvailable = true;
        } catch (e) {
          root.modemAvailable = false;
        }
      }
    }
    onExited: (exitCode) => {
      if (exitCode !== 0) {
        root.modemAvailable = false;
      }
    }
  }

  // --- Polling timer ---
  Timer {
    id: pollTimer
    interval: root.pollingInterval
    running: true
    repeat: true
    triggeredOnStart: false
    onTriggered: {
      if (root.modemAvailable && root.modemIndex !== "") {
        statusProcess.running = true;
      } else {
        listProcess.running = true;
      }
    }
  }

  // --- Initial discovery on load ---
  Component.onCompleted: {
    listProcess.running = true;
  }
}
