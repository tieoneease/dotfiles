import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
    id: root

    property var pluginApi

    // Reactive state — read by ControlCenterWidget via pluginApi.mainInstance
    property bool inhibited: false

    visible: false

    // --- systemd-inhibit process (--what=sleep blocks suspend/hibernate
    //     but does NOT block the idle hint, so swayidle screen-off still works) ---
    Process {
        id: inhibitorProcess
        command: [
            "systemd-inhibit",
            "--what=sleep",
            "--why=Sleep inhibitor (Noctalia plugin)",
            "--mode=block",
            "sleep", "infinity"
        ]

        onStarted: {
            root.inhibited = true;
            Logger.i("SleepInhibitor", "Inhibitor process started");
        }

        onExited: (exitCode, exitStatus) => {
            root.inhibited = false;
            Logger.i("SleepInhibitor", "Inhibitor process exited:", exitCode);
        }
    }

    function toggle() {
        if (inhibited) {
            stop();
        } else {
            start();
        }
    }

    function start() {
        if (inhibitorProcess.running)
            return;
        inhibitorProcess.running = true;
        if (pluginApi) {
            pluginApi.pluginSettings.enabled = true;
            pluginApi.saveSettings();
        }
    }

    function stop() {
        if (!inhibitorProcess.running)
            return;
        inhibitorProcess.signal(15); // SIGTERM
        if (pluginApi) {
            pluginApi.pluginSettings.enabled = false;
            pluginApi.saveSettings();
        }
    }

    // Restore state from settings on startup
    Component.onCompleted: {
        if (pluginApi && pluginApi.pluginSettings && pluginApi.pluginSettings.enabled) {
            Logger.i("SleepInhibitor", "Restoring inhibitor from saved state");
            start();
        }
    }

    // Clean up on shutdown
    Component.onDestruction: {
        if (inhibitorProcess.running) {
            inhibitorProcess.signal(15);
        }
    }

    // --- IPC handler ---
    IpcHandler {
        target: "plugin:sleep-inhibitor"

        function toggle() {
            root.toggle();
        }

        function enable() {
            root.start();
        }

        function disable() {
            root.stop();
        }
    }
}
