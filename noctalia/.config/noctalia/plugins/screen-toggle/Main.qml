import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var pluginApi

  // Reactive state properties
  property bool screenAvailable: false
  property bool screenEnabled: false

  visible: false

  // Poll interval from plugin settings, default 5s
  readonly property int pollingInterval: {
    if (pluginApi && pluginApi.pluginSettings && pluginApi.pluginSettings.pollingInterval)
      return pluginApi.pluginSettings.pollingInterval;
    return 5000;
  }

  // --- Query niri outputs for eDP-2 state ---
  Process {
    id: queryProcess
    command: ["niri", "msg", "-j", "outputs"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var result = JSON.parse(text);
          if (result["eDP-2"] !== undefined) {
            root.screenAvailable = true;
            root.screenEnabled = result["eDP-2"].current_mode !== null;
          } else {
            root.screenAvailable = false;
            root.screenEnabled = false;
          }
        } catch (e) {
          root.screenAvailable = false;
          root.screenEnabled = false;
        }
      }
    }
    onExited: (exitCode) => {
      if (exitCode !== 0) {
        root.screenAvailable = false;
        root.screenEnabled = false;
      }
    }
  }

  // --- Toggle eDP-2 on/off ---
  function toggle() {
    if (!screenAvailable)
      return;
    if (screenEnabled) {
      turnOffProcess.running = true;
    } else {
      turnOnProcess.running = true;
    }
  }

  Process {
    id: turnOffProcess
    command: ["niri", "msg", "output", "eDP-2", "off"]
    onExited: {
      // Re-query state after toggle
      queryProcess.running = true;
    }
  }

  // Turn on requires positioning eDP-2 below eDP-1
  Process {
    id: turnOnProcess
    command: ["niri", "msg", "output", "eDP-2", "on"]
    onExited: {
      // Small delay to let niri register the output before positioning
      positionDelay.start();
    }
  }

  Timer {
    id: positionDelay
    interval: 500
    repeat: false
    onTriggered: {
      positionQueryProcess.running = true;
    }
  }

  // Query eDP-1 height to compute eDP-2 y position
  Process {
    id: positionQueryProcess
    command: ["niri", "msg", "-j", "outputs"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var result = JSON.parse(text);
          var y = result["eDP-1"].logical.height + 1;
          positionProcess.command = ["niri", "msg", "output", "eDP-2", "position", "set", "0", String(y)];
          positionProcess.running = true;
        } catch (e) {
          // Fallback: re-query state
          queryProcess.running = true;
        }
      }
    }
  }

  Process {
    id: positionProcess
    command: ["niri", "msg", "output", "eDP-2", "position", "set", "0", "1029"]
    onExited: {
      queryProcess.running = true;
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
      queryProcess.running = true;
    }
  }

  // --- Initial query on load ---
  Component.onCompleted: {
    queryProcess.running = true;
  }
}
