#!/usr/bin/env bash
set -euo pipefail

# lid-display-handler.sh — manages display power on lid close/open events
#
# When the sleep-inhibitor plugin is active (--what=sleep, --mode=block):
#   - LidSwitchIgnoreInhibited=no means logind skips suspend on lid close
#   - This script powers off monitors so they don't burn under the closed lid
#   - On lid open, monitors power back on
#
# When no inhibitor is active:
#   - Lid close → logind suspends normally (s2idle)
#   - This script does nothing on lid close (suspend handles displays)
#   - On lid open (resume), it powers monitors back on as a safety net

is_sleep_inhibited() {
    systemd-inhibit --list 2>/dev/null | grep -q "Sleep inhibitor (Noctalia plugin)"
}

# Monitor logind's LidClosed property changes via D-Bus
gdbus monitor --system \
    --dest org.freedesktop.login1 \
    --object-path /org/freedesktop/login1 2>/dev/null |
while IFS= read -r line; do
    if [[ "$line" == *"'LidClosed'"*"<true>"* ]]; then
        # Lid closed
        if is_sleep_inhibited; then
            # Inhibitor active: suspend is blocked, power off displays ourselves
            niri msg action power-off-monitors 2>/dev/null || true
        fi
        # If not inhibited, logind handles suspend — displays go off naturally
    elif [[ "$line" == *"'LidClosed'"*"<false>"* ]]; then
        # Lid opened — always power on monitors
        # (covers both resume-from-suspend and inhibited-lid-close cases)
        niri msg action power-on-monitors 2>/dev/null || true
    fi
done
