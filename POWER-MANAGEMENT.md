# Power Management — Full Diagnosis

Both machines, all power states, real-world behavior, what's broken, what to simplify.

**Machines:**
- **sam-duomoon** — ASUS Zenbook Duo 2024, EndeavourOS, Intel
- **sam-ganymede** — GPD Win Max 2, CachyOS, AMD Phoenix (currently connected)

---

## 1. Hardware Reality

| | Zenbook Duo (sam-duomoon) | GPD Win Max 2 (sam-ganymede) |
|---|---|---|
| **CPU** | Intel (likely Meteor Lake) | AMD Phoenix (Ryzen 7 7840U) |
| **ACPI sleep states** | S0, S3, S4, S5 | **S0, S4, S5 only — no S3** |
| **mem_sleep** | s2idle (default), deep (S3 available) | **s2idle only** |
| **S0ix (modern standby)** | Likely functional (Intel has good S0ix) | **Broken — residency = 0** |
| **Swap** | Unknown (need to check) | zram only (12.5G, RAM-backed, volatile) |
| **Hibernate** | Unknown (probably no disk swap) | **Impossible** (no disk swap, no `resume=` kernel param) |
| **Kernel** | Stock `linux` | `linux-cachyos` 6.19.5 (EEVDF + LTO + AutoFDO) |
| **Battery** | Unknown | ~60Wh, currently drawing ~13W awake |
| **Fan** | Unknown | 2122 RPM at idle (44°C) |

The distros (EndeavourOS vs CachyOS) are both Arch underneath. Their power management
stacks are identical (systemd, logind, swayidle). The differences that matter are
**hardware** (Intel vs AMD Phoenix, different ACPI tables, different firmware) and
**CachyOS extras** (ananicy-cpp, zram-only swap, cachyos kernel) — none of which
affect suspend behavior.

---

## 2. Power States — What Actually Happens

### Awake (normal use)

| Observation | sam-ganymede (observed) | sam-duomoon (expected) |
|---|---|---|
| **Processes** | All running normally | Same |
| **CPU** | Active, 1400–2200 MHz, powersave governor | Same |
| **Temperature** | 44°C CPU, 40°C WiFi | Similar |
| **Fan** | ~2100 RPM | Varies |
| **Power draw** | ~13W from battery | Similar |
| **Network** | Connected (WiFi, Tailscale) | Same |
| **Screen** | On | Same |

### Screen locked (swayidle 5 min timeout)

| Observation | Both machines |
|---|---|
| **Trigger** | swayidle fires after 300s idle → calls `qs -c noctalia-shell ipc call lockScreen lock` |
| **Processes** | All still running. Every process continues executing. |
| **CPU/GPU** | Still active, rendering the lock screen |
| **Temperature** | Same as awake |
| **Fan** | Same as awake |
| **Power draw** | Same as awake (screen still on, processes running) |
| **Network** | Still connected |
| **Screen** | On, showing Noctalia lock screen |
| **Resume** | Any input → unlock prompt → type password → back to desktop |
| **Data loss risk** | None — nothing is suspended |

### Monitors off (swayidle 10 min timeout)

| Observation | Both machines |
|---|---|
| **Trigger** | swayidle fires after 600s → calls `niri msg action power-off-monitors` (DPMS off) |
| **Processes** | All still running |
| **CPU** | Still active (no GPU rendering, so slightly less load) |
| **Temperature** | Slightly cooler (no display rendering) |
| **Fan** | Slightly slower |
| **Power draw** | ~2-4W less (display backlight off) |
| **Network** | Still connected |
| **Screen** | Off (DPMS) |
| **Resume** | Any input → monitors power on → lock screen visible → type password |
| **Data loss risk** | None |

### s2idle suspend — WHEN IT WORKS (Intel / sam-duomoon expected)

| Observation | Expected behavior |
|---|---|
| **Trigger** | Lid close → logind → `systemctl suspend` → kernel enters s2idle |
| **Processes** | **Frozen.** All userspace processes are stopped by the kernel's freezer. No code executes. Process state is preserved in RAM. |
| **CPU** | Enters deepest C-state (S0ix). Most of the SoC powers down. Only a tiny wakeup controller stays alive. |
| **Temperature** | Drops to near-ambient within minutes |
| **Fan** | Off |
| **Power draw** | **~0.5–2W** (similar to S3 deep sleep) |
| **Network** | **Disconnected.** WiFi firmware is suspended. NetworkManager puts interfaces to sleep before suspend, restores on resume. |
| **Screen** | Off |
| **RAM** | **Powered** (contents preserved, but in self-refresh/low-power mode) |
| **Resume** | Lid open or power button → kernel unfreezes processes → NetworkManager reconnects WiFi → lock screen appears → type password → back to desktop. Takes ~1-3 seconds. |
| **Battery life** | Days of standby on a full charge |
| **Data loss risk** | Low — RAM contents preserved. Only risk: battery dies completely → RAM contents lost → equivalent to a crash. |

### s2idle suspend — WHEN IT'S BROKEN (AMD Phoenix / sam-ganymede actual)

This is what's happening to your GPD Win Max 2 **right now.**

| Observation | Actual behavior (verified from journal) |
|---|---|
| **Trigger** | Lid close → logind → `systemctl suspend` → kernel enters s2idle |
| **Processes** | **Frozen** (this part works). Kernel freezer stops all userspace processes. |
| **CPU** | **Fails to enter S0ix.** `S0ix Residency Time: 0`. The CPU parks in a shallow C-state — still drawing significant power, silicon still partially active. |
| **Temperature** | **Stays hot.** CPU/SoC doesn't cool down because it never reaches deep idle. In a closed bag, heat builds up with no airflow. |
| **Fan** | May spin intermittently to manage heat |
| **Power draw** | **~5-15W** (nearly the same as idle with screen off) |
| **Network** | Disconnected (NetworkManager still suspends interfaces properly) |
| **Screen** | Off |
| **RAM** | Powered (contents preserved) |
| **Resume** | Lid open → processes unfreeze → WiFi reconnects → you see the desktop. Takes ~1-3 seconds. **But:** on boot -3, 12 seconds after lid-open resume, logind triggered **poweroff** (`HandlePowerKey=poweroff` is the default — override was never deployed). All processes killed, unsaved work lost. |
| **Battery life** | **~4-6 hours** (draining at near-active rate while "suspended") |
| **In a bag** | **Hot laptop, battery draining, fans may spin.** This is your exact problem. |
| **Data loss risk** | Medium — battery drains fast during "suspend", and if it dies, RAM is lost. Also: the one time it DID suspend and resume, it immediately powered off (see forensics below). |

**Forensic evidence from boot -3 (the one real suspend):**
```
01:32:26  Lid closed
01:32:27  PM: suspend entry (s2idle)            ← kernel freezes processes
  ... 1 hour 29 minutes pass, S0ix residency = 0, machine burning battery ...
03:01:17  Lid opened → resume
03:01:17  HHD: "Waking up from sleep"           ← processes unfreeze
03:01:17  PM: suspend exit
03:01:21  WiFi reconnects
03:01:29  logind: "The system will power off now!"  ← SHUTDOWN triggered
03:01:30  All services killed, filesystem unmounted
          Boot -2 starts 43 minutes later (you had to manually power on)
```

The resume→immediate-poweroff happened because `HandlePowerKey` defaults to `poweroff`
(the logind override was never deployed on this machine), and something during the
resume sequence generated a power-key event that logind interpreted as a shutdown request.

### S3 deep sleep (Zenbook Duo only — broken)

| Observation | sam-duomoon (known broken) |
|---|---|
| **Trigger** | Would need `MemorySleepMode=deep` in sleep.conf (currently not set) |
| **Processes** | Frozen by kernel, state preserved in RAM |
| **CPU** | Fully powered off (real hardware sleep) |
| **Power draw** | ~0.3-1W |
| **Resume** | **Fails on lid close.** System hangs on resume → hard restart required → unsaved work lost. |
| **Status** | Correctly avoided. `arch_setup.sh` actively removes any `10-deep-sleep.conf`. |

### Hibernate (S4) — currently impossible on both machines

| Observation | What would happen if properly configured |
|---|---|
| **Trigger** | `systemctl hibernate` or logind `HandleLidSwitch=hibernate` |
| **Processes** | Frozen, full RAM contents written to swap on disk, then system powers off completely |
| **CPU** | **Off.** Machine is fully powered down. |
| **Temperature** | Ambient (machine is off) |
| **Fan** | Off |
| **Power draw** | **0W** (machine is off, like shutdown) |
| **Network** | Off |
| **Screen** | Off |
| **RAM** | **Unpowered.** Contents were saved to disk swap. |
| **Resume** | Power button → BIOS POST → bootloader → kernel reads RAM image from swap → processes resume from where they were. Takes ~10-20 seconds. |
| **Battery life** | Infinite (machine is off) |
| **Data loss risk** | Very low — state is on non-volatile storage. Only risk: disk failure. |
| **Why impossible now** | **sam-ganymede:** only has zram swap (volatile, RAM-backed — destroyed on poweroff). No disk-backed swap file/partition. No `resume=` kernel parameter. **sam-duomoon:** likely the same situation. |

### Suspend-then-hibernate (the ideal solution — not configured)

| Observation | What would happen if configured |
|---|---|
| **Trigger** | Lid close → logind → s2idle first, then auto-hibernate after delay |
| **Phase 1 (0–15 min)** | s2idle. If S0ix works: low power. If S0ix is broken: draws ~5-15W but that's only for 15 minutes, not hours. |
| **Phase 2 (after 15 min)** | systemd wakes the machine internally, writes RAM to disk swap, powers off completely. |
| **Power draw** | ~5-15W for 15 min, then **0W** forever |
| **Resume (from s2idle phase)** | Quick, ~1-3 seconds, same as normal s2idle |
| **Resume (from hibernate phase)** | Slower, ~10-20 seconds, reads RAM image from disk |
| **Battery life** | At worst, loses ~15min × 15W = ~3.75Wh then zero drain. Even with broken S0ix, battery lasts for weeks. |
| **Data loss risk** | Very low — if s2idle battery runs out in 15 min window (very unlikely), hibernate hasn't happened yet. But 15 min at 15W is only ~3.75Wh out of ~60Wh battery. |

---

## 3. What Each Trigger Actually Does (Right Now)

### sam-ganymede (GPD Win Max 2) — Current Actual Behavior

| Trigger | What happens | What you experience |
|---|---|---|
| **Lid close** | logind sees `HandleLidSwitch=suspend` (default) → `systemctl suspend` → s2idle (broken S0ix) | Laptop "sleeps" but stays hot, drains battery at ~5-15W. In a bag: hot, dead battery hours later. |
| **Lid open** | s2idle resumes → processes unfreeze → you see desktop/lock screen | Instant resume, but last time it immediately powered off 12s later (HandlePowerKey=poweroff bug). |
| **Power button press** | `HandlePowerKey=poweroff` (default, **override not deployed**) → full shutdown | **Machine powers off.** All unsaved work is lost. You think you're suspending, but it's shutting down. |
| **5 min idle** | swayidle → Noctalia lock screen via IPC | Screen shows lock UI. All processes still running, full power draw. |
| **10 min idle** | swayidle → `niri msg action power-off-monitors` | Screen goes dark. All processes still running. Slightly less power (~2-4W saved from display). |
| **Sleep inhibitor ON + lid close** | `LidSwitchIgnoreInhibited=yes` (default, **override not deployed**) → logind ignores inhibitor → suspends anyway | The sleep-inhibitor plugin has no effect on lid close. It's a no-op. |
| **Sleep inhibitor ON + power button** | `PowerKeyIgnoreInhibited=no` (default, **override not deployed**) → logind checks inhibitors → if held, skips action | Power button does nothing while inhibitor is active. But since HandlePowerKey=poweroff, this means the inhibitor "protects" you from accidental shutdown — accidentally correct behavior for the wrong reason. |
| **KeepAwake (built-in) ON** | `systemd-inhibit --what=idle` → blocks swayidle idle detection | Screen stays on, no auto-lock, no DPMS off. Logind still suspends on lid close. |
| **Hibernate** | `systemctl hibernate` → fails: no disk swap, no resume= param | Error. Nothing happens. |

### sam-duomoon (Zenbook Duo) — Expected Behavior (logind override IS deployed)

| Trigger | What happens | What you experience |
|---|---|---|
| **Lid close** | logind `HandleLidSwitch=suspend` → s2idle (Intel S0ix likely works) | Laptop suspends properly, stays cool, low battery drain. |
| **Lid open** | s2idle resume → processes unfreeze → lock screen | Quick resume (~1-3s), WiFi reconnects, back to work. |
| **Power button press** | `HandlePowerKey=suspend` (override deployed) → s2idle suspend | Same as lid close. Always works (`PowerKeyIgnoreInhibited=yes`). |
| **5 min idle** | Same as GPD (swayidle → lock) | Lock screen appears. |
| **10 min idle** | Same as GPD (swayidle → DPMS off) | Screen goes dark. |
| **Sleep inhibitor ON + lid close** | `LidSwitchIgnoreInhibited=no` (override deployed) → logind respects inhibitor → skips suspend → lid-display-handler.sh powers off monitors | Laptop stays running with lid closed, screen off. Good for downloads. |
| **Sleep inhibitor ON + power button** | `PowerKeyIgnoreInhibited=yes` (override deployed) → logind ignores inhibitor → suspends anyway | Power button always suspends, even with inhibitor. Escape hatch. |
| **KeepAwake (built-in) ON** | Same as GPD: blocks swayidle | Screen stays on. |
| **Hibernate** | Probably fails (no disk swap configured) | Error. |

---

## 4. What's Broken — Ranked by Impact

### sam-ganymede (GPD Win Max 2) — 🔴 Critical Issues

| # | Issue | Impact | Root Cause |
|---|---|---|---|
| 1 | **S0ix residency = 0** | Laptop stays hot in bag, battery drains in hours during "suspend" | AMD Phoenix firmware/driver issue. CPU never enters deep idle during s2idle. Common problem on this chipset. |
| 2 | **logind override not deployed** | Power button = **shutdown** (not suspend). Sleep inhibitor doesn't work on lid close. | `10-power-and-lid.conf` is only copied inside the `asus_setup` block in `arch_setup.sh`. This machine skips that block. `/etc/systemd/logind.conf.d/` doesn't even exist. |
| 3 | **Resume → immediate poweroff** | After the one successful suspend (boot -3), opening the lid triggered resume, then logind powered off the machine 12s later. All processes killed. | `HandlePowerKey=poweroff` (default). A power-key event during resume was interpreted as a shutdown request. |
| 4 | **No hibernate capability** | No safe power-off-with-state-preservation. If s2idle drains the battery, everything is lost. | zram-only swap (CachyOS default). No disk-backed swap. No `resume=` kernel param. |

### sam-duomoon (Zenbook Duo) — 🟡 Minor Issues

| # | Issue | Impact | Root Cause |
|---|---|---|---|
| 1 | **S3 deep sleep broken** | Can't use the most power-efficient sleep state | ASUS firmware bug — fails to resume from S3 on lid close. s2idle works as fallback. |
| 2 | **No hibernate** | Same as GPD — no safe state preservation for extended sleep | Probably no disk swap configured. |
| 3 | **s2idle quality unverified** | Might be fine (Intel S0ix is usually reliable) or might have issues | Can't check — machine is offline. |

---

## 5. The Custom Stuff — What We Built and Whether It's Hacky

### `10-power-and-lid.conf` (logind override)

**What it does:** Sets `HandlePowerKey=suspend`, `PowerKeyIgnoreInhibited=yes`,
`LidSwitchIgnoreInhibited=no`.

**Verdict: ✅ Not hacky.** This is standard systemd logind configuration. It's the
correct way to change power button and lid behavior. The only problem is a deployment
bug — it's gated behind `asus_setup` in `arch_setup.sh` instead of being deployed on
all machines.

### `disable-power-key-handling` in niri config

**What it does:** Tells niri not to intercept the power key, delegating to logind.

**Verdict: ✅ Not hacky.** Standard niri configuration option. Works around a real
niri bug (#2233) where niri sees the wake-from-suspend power key event and immediately
re-suspends.

### swayidle (idle timeout → lock, DPMS, lock-before-suspend)

**What it does:** Three things:
1. 5 min idle → call Noctalia IPC to lock screen
2. 10 min idle → tell niri to DPMS-off monitors
3. Before suspend → call Noctalia IPC to lock screen

**Verdict: ⚠️ Partially redundant.** swayidle is the standard tool for idle management
on Wayland, and Noctalia doesn't have built-in idle timers — so #1 and #2 are necessary.
But #3 (before-sleep lock) duplicates Noctalia's built-in `lockOnSuspend` setting, which
is currently turned OFF. We should enable the Noctalia setting and drop the swayidle
`before-sleep` clause.

### sleep-inhibitor plugin (custom Noctalia plugin)

**What it does:** `systemd-inhibit --what=sleep --mode=block` — blocks suspend while
allowing screen to turn off (swayidle DPMS still works).

**Verdict: ⚠️ Adds complexity for a rare use case.** This exists because the built-in
KeepAwake uses `--what=idle`, which blocks swayidle entirely (no screen off, no auto-lock,
no DPMS). Our plugin uses `--what=sleep` to get "screen can turn off, but don't suspend"
behavior. This is a real use case (downloads, long tasks), but it requires three supporting
components:

- The plugin itself (3 QML files)
- `LidSwitchIgnoreInhibited=no` in logind config (otherwise lid close ignores inhibitors)
- `lid-display-handler.sh` (powers off monitors on lid close when inhibited, since the
  display would otherwise stay on under the closed lid)

If the "download mode" use case isn't common enough, removing all three simplifies the
stack significantly. You can always run `systemd-inhibit --what=sleep sleep infinity &`
manually in a terminal for the rare occasion you need it.

### lid-display-handler.sh

**What it does:** Monitors logind's `LidClosed` D-Bus property. When lid closes with sleep
inhibitor active, powers off monitors via niri. On lid open, powers them back on.

**Verdict: ⚠️ Consequence of the sleep-inhibitor design.** Only exists because
`LidSwitchIgnoreInhibited=no` lets the sleep-inhibitor block lid-close suspend, but then
the screen stays on under the closed lid. If we remove the sleep-inhibitor plugin and
revert `LidSwitchIgnoreInhibited` to default, this script becomes unnecessary.

**Also buggy:** On sam-ganymede it spawned but the parent bash process appears to be running
while doing nothing useful, and it's not robust against crashes (no systemd restart, no
watchdog).

### Noctalia lockOnSuspend setting

**What it does:** When enabled, Noctalia automatically locks the screen before the system
suspends (listens for systemd's PrepareForSleep signal or equivalent).

**Current state:** OFF. We use swayidle `before-sleep` instead.

**Verdict: 🔴 Should be ON.** This is built into Noctalia and does the same thing as our
swayidle `before-sleep` clause. Enabling it and removing the swayidle clause means one less
external tool dependency for this behavior.

### Noctalia built-in KeepAwake

**What it does:** `systemd-inhibit --what=idle` — blocks the idle hint, which prevents
swayidle from firing any timeouts.

**Verdict: ✅ Keep.** Standard Noctalia feature. When ON: screen stays on, no auto-lock,
no DPMS. Useful for presentations, watching video. Doesn't directly block suspend (lid close
still suspends), which is correct behavior — you want the machine to suspend when you close
the lid even during a presentation.

---

## 6. Overlapping Responsibilities — The Confusion Map

```
         IDLE TIMER          LOCK            DPMS OFF        BLOCK SUSPEND     LID CLOSE DISPLAY
         ─────────           ────            ────────        ─────────────     ──────────────────
swayidle ✅ (300s/600s)      ✅ (via IPC)    ✅ (via niri)   ❌                ❌
Noctalia ❌ (no idle timer)  ✅ (lock IPC)   ❌              ❌                ❌
         lockOnSuspend OFF→  ✅ (if enabled) ❌              ❌                ❌
         KeepAwake           blocks swayidle blocks swayidle ❌ (--what=idle)  ❌
         sleep-inhibitor     ❌              ❌              ✅ (--what=sleep) ❌
logind   ❌                  ❌              ❌              respects inhibitors  triggers suspend
lid-display-handler.sh  ❌   ❌              ❌              ❌                ✅ (power off monitors)
```

Four systems, partially overlapping, some redundant, some with broken deployment.

---

## 7. Simplification Plan

### Phase 1: Fix critical bugs (immediate)

1. **Move logind config deployment out of `asus_setup` block** in `arch_setup.sh`.
   The `HandlePowerKey=suspend` and `PowerKeyIgnoreInhibited=yes` settings apply to
   ALL laptops. Move to the common section before any machine-specific blocks.

2. **Deploy logind override on sam-ganymede right now:**
   ```bash
   sudo mkdir -p /etc/systemd/logind.conf.d
   sudo cp ~/dotfiles/etc/systemd/logind.conf.d/10-power-and-lid.conf /etc/systemd/logind.conf.d/
   sudo systemctl restart systemd-logind
   ```
   After this: power button = suspend, not poweroff.

### Phase 2: Simplify the stack

3. **Enable Noctalia `lockOnSuspend`** — set to `true` in `settings.json` and
   `settings.default.json`. Remove the `before-sleep` clause from the swayidle
   command in `config.kdl`. Result:
   ```
   swayidle -w \
       timeout 300 'qs -c noctalia-shell ipc call lockScreen lock' \
       timeout 600 'niri msg action power-off-monitors' \
       resume 'niri msg action power-on-monitors'
   ```

4. **Remove the sleep-inhibitor plugin** — delete the 3 QML files + manifest from
   `noctalia/.config/noctalia/plugins/sleep-inhibitor/`. Remove the CC widget entry
   from `settings.json`. The built-in KeepAwake covers the "keep screen on" use case.

5. **Remove lid-display-handler.sh** — delete the file and its `spawn-sh-at-startup`
   line from `config.kdl`. Without the sleep-inhibitor plugin, there's no scenario
   where the system stays running with the lid closed (logind just suspends).

6. **Remove `LidSwitchIgnoreInhibited=no`** from `10-power-and-lid.conf`. Revert to
   the default (`yes`). Without the custom sleep-inhibitor, we don't need logind to
   respect inhibitors on lid events. Simplified config:
   ```ini
   [Login]
   HandlePowerKey=suspend
   PowerKeyIgnoreInhibited=yes
   ```

### Phase 3: Fix the real problem (s2idle / hibernate)

7. **Diagnose S0ix on sam-ganymede** — after deploying the logind fix, do a test
   suspend cycle and check residency:
   ```bash
   sudo systemctl suspend    # wake with power button
   sudo cat /sys/kernel/debug/amd_pmc/s0ix_stats
   ```

8. **If S0ix is still broken (likely): set up suspend-then-hibernate.** This is the
   standard, non-hacky solution for AMD laptops with broken s2idle.

   a. Create swap file on NVMe (needs ≥12GB, use 16GB for margin):
   ```bash
   sudo btrfs filesystem mkswapfile --size 16G /swap/swapfile
   sudo swapon /swap/swapfile
   # Add to /etc/fstab: /swap/swapfile none swap defaults 0 0
   ```

   b. Get resume offset:
   ```bash
   sudo btrfs inspect-internal map-swapfile -r /swap/swapfile
   ```

   c. Add kernel parameters:
   ```
   resume=UUID=8ca6be01-1e97-41ed-ab16-a1db405520e8 resume_offset=<offset>
   ```

   d. Configure sleep.conf:
   ```ini
   # /etc/systemd/sleep.conf.d/10-suspend-then-hibernate.conf
   [Sleep]
   HibernateDelaySec=15min
   ```

   e. Update logind:
   ```ini
   HandleLidSwitch=suspend-then-hibernate
   HandlePowerKey=suspend-then-hibernate
   ```

   **Result:** Lid close → s2idle for 15 min (quick resume if you open lid soon) →
   auto-hibernate to disk (0W, safe, resume in ~15s). Even if S0ix is broken, you
   only burn ~3.75Wh in that 15-minute window, not your entire battery.

---

## 8. After Simplification — What Each Trigger Does

### Both machines (common behavior)

| Trigger | What happens |
|---|---|
| **5 min idle** | swayidle → Noctalia lock screen. All processes still running, screen shows lock UI. |
| **10 min idle** | swayidle → monitors DPMS off. All processes still running, screen dark, slightly less power. Any input wakes monitors → lock screen. |
| **KeepAwake ON** | `--what=idle` blocks swayidle. Screen stays on, no auto-lock, no DPMS. Lid close still suspends (KeepAwake doesn't block suspend). |
| **KeepAwake OFF** | Normal idle behavior (lock at 5min, DPMS at 10min). |

### sam-duomoon (Zenbook Duo) — after simplification

| Trigger | What happens |
|---|---|
| **Lid close** | logind → s2idle. Processes frozen. CPU enters S0ix (Intel). Low power (~1-2W). Cool. |
| **Lid open** | Resume ~1-3s. Noctalia lock screen (was locked by lockOnSuspend before suspend). Type password. |
| **Power button** | Same as lid close (suspend). Always works, even during KeepAwake. |
| **Hibernate** | Not configured (optional future improvement). |

### sam-ganymede (GPD Win Max 2) — after simplification + suspend-then-hibernate

| Trigger | What happens |
|---|---|
| **Lid close** | logind → suspend-then-hibernate. Phase 1: s2idle for 15 min. Phase 2: hibernate to disk (0W). |
| **Lid open (within 15 min)** | Quick resume from s2idle (~1-3s). Lock screen. |
| **Lid open (after 15 min)** | Resume from hibernate (~10-20s). BIOS POST → kernel loads RAM from swap → lock screen. |
| **Power button** | Same as lid close (suspend-then-hibernate). Always works. |
| **In a bag** | s2idle for 15 min (maybe warm, ~3.75Wh worst case), then fully off (0W, cool, indefinite). **No more hot laptop.** |

---

## 9. Components After Cleanup

### Keep

| Component | Why |
|---|---|
| `10-power-and-lid.conf` (simplified) | `HandlePowerKey=suspend[-then-hibernate]`, `PowerKeyIgnoreInhibited=yes`. Standard logind config. |
| `disable-power-key-handling` in niri | Works around niri bug #2233. Standard niri option. |
| swayidle (simplified) | Idle lock (300s) + DPMS off (600s) + resume. No `before-sleep`. Noctalia has no built-in idle timer. |
| Noctalia `lockOnSuspend=true` | Replaces swayidle `before-sleep`. Native Noctalia feature. |
| Noctalia built-in KeepAwake | "Presentation mode" — screen stays on. Standard feature. |
| `wireplumber/51-no-suspend.conf` | Unrelated to system suspend. Prevents audio node idle-suspend (Discord muting fix). |

### Remove

| Component | Files | Why |
|---|---|---|
| sleep-inhibitor plugin | `noctalia/.config/noctalia/plugins/sleep-inhibitor/` (Main.qml, ControlCenterWidget.qml, manifest.json) | Replaced by built-in KeepAwake. Removes need for lid-display-handler and special logind config. |
| lid-display-handler.sh | `niri/.config/niri/lid-display-handler.sh` + spawn line in `config.kdl` | Only existed to support sleep-inhibitor. Fragile (no restart on crash). |
| `LidSwitchIgnoreInhibited=no` | Line in `10-power-and-lid.conf` | Only needed for sleep-inhibitor. Default (`yes`) is correct without it. |
| swayidle `before-sleep` clause | Part of swayidle command in `config.kdl` | Replaced by Noctalia `lockOnSuspend`. |

### Add (for sam-ganymede)

| Component | Files | Why |
|---|---|---|
| Swap file | `/swap/swapfile` (16GB on NVMe) | Required for hibernate. |
| sleep.conf | `/etc/systemd/sleep.conf.d/10-suspend-then-hibernate.conf` | `HibernateDelaySec=15min` |
| Kernel params | `resume=UUID=... resume_offset=...` | Required for hibernate resume. |
| logind update | `HandleLidSwitch=suspend-then-hibernate` | Uses the new hibernate capability. |

---

## 10. Summary

The "hot laptop in bag" problem has three compounding causes:

1. **AMD Phoenix S0ix is broken** (hardware/firmware) — s2idle doesn't actually save power
2. **logind override wasn't deployed** — power button shuts down instead of suspending,
   and the one time the machine did suspend and resume, it immediately powered off
3. **No hibernate fallback** — zram-only swap can't persist across power-off, so there's
   no safety net when s2idle fails

The custom sleep-inhibitor/lid-display-handler/LidSwitchIgnoreInhibited stack isn't the
source of the problem, but it adds complexity without solving it. Removing those three
custom components and enabling Noctalia's built-in `lockOnSuspend` simplifies the power
management chain from four interacting systems to two (swayidle for idle timeouts, logind
for suspend/hibernate).

The real fix is **suspend-then-hibernate**: even with broken S0ix, the machine will
auto-hibernate to disk after 15 minutes and draw zero power. This is the standard
solution recommended by Framework, Lenovo, and the Arch Wiki for AMD laptops with
unreliable modern standby.
