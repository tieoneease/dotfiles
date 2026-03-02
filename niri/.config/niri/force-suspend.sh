#!/usr/bin/env bash
set -euo pipefail

# force-suspend.sh — disables sleep inhibitor if active, then suspends (s2idle)
#
# Bound to the power button. Provides a safe "I'm packing up" action that
# always suspends regardless of keep-awake state.

# Disable the sleep inhibitor plugin if it's running
qs -c noctalia-shell ipc call plugin:sleep-inhibitor disable 2>/dev/null || true

# Brief pause to let the inhibitor process exit
sleep 0.3

# Suspend (s2idle — safe on Zenbook Duo, never use deep)
systemctl suspend
