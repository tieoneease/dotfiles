# Power Management

Configuration and architecture for suspend, hibernate, idle lock, and DPMS
across both machines.

**Machines:**
- **sam-duomoon** — ASUS Zenbook Duo 2024, EndeavourOS, Intel
- **sam-ganymede** — GPD Win Max 2, CachyOS, AMD Phoenix

**Last updated:** 2026-03-05

---

## Current Status

### sam-ganymede (GPD Win Max 2) — ✅ Fully configured

| Component | State | Detail |
|---|---|---|
| **Logind base** | ✅ Deployed | `10-power-and-lid.conf` — `HandlePowerKey=suspend`, `PowerKeyIgnoreInhibited=yes` |
| **Suspend-then-hibernate** | ✅ Deployed | `20-suspend-then-hibernate.conf` — overrides lid/power to `suspend-then-hibernate` |
| **sleep.conf** | ✅ Deployed | `HibernateDelaySec=15min` |
| **Swap file (16GB)** | ✅ Active | `/swap/swapfile`, in `/etc/fstab` |
| **Kernel params** | ✅ Active | `resume=UUID=... resume_offset=...` via Limine drop-in |
| **Initramfs resume** | ✅ OK | `systemd` hook handles resume automatically (no separate `resume` hook needed) |
| **Niri power key** | ✅ Disabled | `disable-power-key-handling` — delegates to logind (niri #2233 workaround) |
| **swayidle** | ✅ Simplified | Lock@5min, DPMS@10min, resume — no `before-sleep` clause |
| **Noctalia lockOnSuspend** | ⚠️ Check | `settings.default.json`=`true`, verify live setting in Noctalia UI |
| **sleep-inhibitor plugin** | ✅ Removed | Built-in KeepAwake covers "keep screen on" use case |
| **lid-display-handler.sh** | ✅ Removed | No longer needed without sleep-inhibitor |
| **Hibernate test** | ⏳ Pending | Config deployed, `CanSuspendThenHibernate=yes`, needs real-world test |

### sam-duomoon (Zenbook Duo) — ✅ Base config, no hibernate

| Component | State | Detail |
|---|---|---|
| **Logind base** | ✅ Deployed | Same `10-power-and-lid.conf` (common to all machines) |
| **Suspend mode** | ✅ s2idle | Intel S0ix — expected to work properly (low power during suspend) |
| **Niri / swayidle** | ✅ Same config | Shared niri `config.kdl` |
| **Hibernate** | ❌ Not configured | No disk swap, no resume params. Optional future improvement. |

---

## What Each Trigger Does

### sam-ganymede (after suspend-then-hibernate)

| Trigger | What happens |
|---|---|
| **5 min idle** | swayidle → Noctalia lock screen via IPC. Processes still running. |
| **10 min idle** | swayidle → `niri msg action power-off-monitors` (DPMS off). Processes still running, ~2-4W saved. |
| **Lid close** | logind → suspend-then-hibernate. Phase 1: s2idle for 15 min. Phase 2: hibernate to disk (0W). |
| **Lid open (within 15 min)** | Quick resume from s2idle (~1-3s). Lock screen. |
| **Lid open (after 15 min)** | Resume from hibernate (~10-20s). BIOS POST → kernel loads RAM from swap → lock screen. |
| **Power button** | Same as lid close (suspend-then-hibernate). Always works (`PowerKeyIgnoreInhibited=yes`). |
| **KeepAwake ON** | `--what=idle` blocks swayidle — screen stays on, no auto-lock, no DPMS. Lid close still suspends. |
| **In a bag** | s2idle for 15 min (maybe warm, ~3.75Wh worst case), then fully off (0W, cool, indefinite). |

### sam-duomoon (s2idle only)

| Trigger | What happens |
|---|---|
| **5 min idle** | Same (swayidle → lock). |
| **10 min idle** | Same (swayidle → DPMS off). |
| **Lid close** | logind → `systemctl suspend` → s2idle. Intel S0ix = low power (~0.5-2W). |
| **Lid open** | Resume ~1-3s. Lock screen (if lockOnSuspend enabled). |
| **Power button** | `HandlePowerKey=suspend` → same as lid close. |
| **KeepAwake ON** | Same — blocks swayidle, lid close still suspends. |

---

## Hardware Reality

| | Zenbook Duo (sam-duomoon) | GPD Win Max 2 (sam-ganymede) |
|---|---|---|
| **CPU** | Intel (likely Meteor Lake) | AMD Phoenix (Ryzen 7 7840U) |
| **ACPI sleep states** | S0, S3, S4, S5 | S0, S4, S5 only — no S3 |
| **mem_sleep** | s2idle (default), deep (S3 available) | s2idle only |
| **S0ix (modern standby)** | Likely functional (Intel has good S0ix) | **Broken — residency = 0** |
| **Swap** | Unknown (probably no disk swap) | 16GB `/swap/swapfile` + 12.5GB zram |
| **Hibernate** | Not configured | ✅ Configured (Limine + btrfs swapfile) |
| **Kernel** | Stock `linux` | `linux-cachyos` (EEVDF + LTO + AutoFDO) |
| **Bootloader** | systemd-boot (assumed) | Limine |
| **Battery** | Unknown | ~60Wh |

The distros (EndeavourOS vs CachyOS) are both Arch underneath. Their power management
stacks are identical (systemd, logind, swayidle). The differences that matter are
**hardware** (Intel vs AMD Phoenix, different ACPI tables, different firmware) and
**CachyOS extras** (ananicy-cpp, zram-only swap, cachyos kernel).

---

## Architecture — Active Components

### What's running and why

| Component | Purpose | Config location |
|---|---|---|
| **logind** | Lid close → suspend/hibernate. Power button → suspend/hibernate. | `/etc/systemd/logind.conf.d/*.conf` |
| **swayidle** | Idle lock (5min) + DPMS off (10min) + resume DPMS on | `niri/.config/niri/config.kdl` (spawn-sh-at-startup) |
| **Noctalia lockOnSuspend** | Locks screen before suspend (PrepareForSleep signal) | `noctalia/.config/noctalia/settings.default.json` |
| **Noctalia KeepAwake** | `systemd-inhibit --what=idle` — blocks swayidle timeouts | Built-in Noctalia feature (toggle in UI) |
| **niri `disable-power-key-handling`** | Delegates power key to logind (niri #2233 workaround) | `niri/.config/niri/config.kdl` |
| **wireplumber `51-no-suspend.conf`** | Prevents audio node idle-suspend (Discord muting fix) | `wireplumber/.config/wireplumber/` |

### What was removed (and why)

| Component | Reason |
|---|---|
| sleep-inhibitor plugin | Replaced by built-in KeepAwake. Removing it also removed the need for `lid-display-handler.sh` and `LidSwitchIgnoreInhibited=no`. |
| lid-display-handler.sh | Only existed to support sleep-inhibitor (power off monitors on lid close when inhibited). Fragile, no restart on crash. |
| `LidSwitchIgnoreInhibited=no` | Only needed for sleep-inhibitor. Default (`yes`) is correct without it. |
| swayidle `before-sleep` clause | Replaced by Noctalia `lockOnSuspend=true`. |

---

## Deployed Config Files

### Common (all machines) — `arch_setup.sh` common section

**`/etc/systemd/logind.conf.d/10-power-and-lid.conf`:**
```ini
[Login]
HandlePowerKey=suspend
PowerKeyIgnoreInhibited=yes
```
- Power button suspends (not poweroff, which is the systemd default).
- Power button always works, even when KeepAwake inhibitor is active.

### sam-ganymede only — `arch_setup.sh` GPD section

**`/etc/systemd/logind.conf.d/20-suspend-then-hibernate.conf`:**
```ini
[Login]
HandleLidSwitch=suspend-then-hibernate
HandlePowerKey=suspend-then-hibernate
```
- Overrides the base `10-` config: both lid and power button use suspend-then-hibernate.
- Layering: `20-` sorts after `10-`, so its `HandlePowerKey` wins.
  `PowerKeyIgnoreInhibited=yes` from `10-` still applies (not overridden by `20-`).

**`/etc/systemd/sleep.conf.d/10-suspend-then-hibernate.conf`:**
```ini
[Sleep]
HibernateDelaySec=15min
```
- After 15 minutes of s2idle, systemd auto-hibernates to disk.

**`/etc/limine-entry-tool.d/10-hibernate.conf`:**
```
KERNEL_CMDLINE[default]+="resume=UUID=<root-uuid> resume_offset=<swap-offset>"
```
- Tells the kernel where to find the hibernate image on resume.
- Generated by `arch_setup.sh` from `btrfs inspect-internal map-swapfile`.

**`/swap/swapfile`** (16GB btrfs swapfile):
- Created by `arch_setup.sh`, added to `/etc/fstab`.
- Must be ≥ RAM size for full hibernate (16GB RAM → 16GB swap).
- zram is still active for runtime memory pressure; disk swap is for hibernate.

### swayidle (in niri config.kdl)

```
spawn-sh-at-startup "swayidle -w \
    timeout 300 'qs -c noctalia-shell ipc call lockScreen lock' \
    timeout 600 'niri msg action power-off-monitors' \
    resume 'niri msg action power-on-monitors'"
```
- 5 min idle → lock screen via Noctalia IPC.
- 10 min idle → DPMS off via niri.
- Any input → DPMS on.
- No `before-sleep` clause — Noctalia `lockOnSuspend` handles pre-suspend locking.

---

## Why suspend-then-hibernate (AMD Phoenix S0ix)

AMD Phoenix (Ryzen 7 7840U) has **broken S0ix** — the CPU never enters deep idle
during s2idle. `S0ix Residency Time: 0`. The machine draws ~5-15W while "suspended"
(nearly the same as idle with screen off).

This means:
- Plain s2idle drains the battery in ~4-6 hours
- In a bag: hot laptop, fans may spin, battery dead hours later
- No data loss (RAM stays powered), but useless as "sleep"

**Suspend-then-hibernate** is the standard solution (recommended by Framework, Lenovo,
Arch Wiki): s2idle for 15 minutes (quick resume if you open the lid soon), then
auto-hibernate to disk (0W, indefinite standby). Even with broken S0ix, the 15-minute
window costs only ~3.75Wh out of a ~60Wh battery.

To verify S0ix status after a suspend:
```bash
sudo systemctl suspend    # wake with power button after a few seconds
sudo cat /sys/kernel/debug/amd_pmc/s0ix_stats
```

---

## Initramfs & Resume (CachyOS / mkinitcpio)

CachyOS uses `mkinitcpio` with a **systemd-based initramfs**:
```
HOOKS=(base systemd autodetect microcode kms modconf block keyboard sd-vconsole plymouth filesystems)
```

The `systemd` hook (not `udev`) means hibernate resume is handled automatically by
`systemd-hibernate-resume-generator` — **no separate `resume` hook is needed**.
The generator reads `resume=` and `resume_offset=` from the kernel command line
and creates the appropriate resume service.

---

## Operational Notes

### Never restart systemd-logind on a live session

**`systemctl restart systemd-logind` kills ALL user sessions**, including niri.
This is because logind manages session lifecycle — restarting it destroys every
active session, which terminates the compositor and all running applications.

To apply logind config changes:
1. Deploy config files to `/etc/systemd/logind.conf.d/`
2. **Reboot** when convenient (or at end of setup script)
3. Changes also take effect on next login after session ends normally

The `arch_setup.sh` script deploys configs with `cp -f` and does NOT restart logind.
The configs take effect on the next reboot (which the script recommends at the end).

### Testing hibernate

Before relying on suspend-then-hibernate for daily use, test hibernate directly:
```bash
# Save all work first!
systemctl hibernate
# Machine should power off completely, then resume on power button press
```

If hibernate fails (black screen, boot loop, etc.):
- Check `journalctl -b -1 | grep -i hibernate` for errors
- Verify swap is active: `swapon --show`
- Verify kernel params: `cat /proc/cmdline | tr ' ' '\n' | grep resume`
- Verify systemd agrees: `busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager CanHibernate`

### S3 deep sleep (Zenbook Duo — known broken)

The Zenbook Duo has S3 available (`mem_sleep` shows `deep`) but resuming from S3
on lid close is broken (system hangs → hard restart → data loss). `arch_setup.sh`
actively removes any `10-deep-sleep.conf` that might force S3.

s2idle with Intel S0ix is the correct sleep mode for this machine.

---

## History & Diagnosis

<details>
<summary>Original diagnosis (2026-03 — expanded)</summary>

### The "hot laptop in bag" problem

Three compounding causes on sam-ganymede:

1. **AMD Phoenix S0ix is broken** — s2idle doesn't actually save power (residency = 0)
2. **logind override wasn't deployed** — power button was shutting down (default
   `HandlePowerKey=poweroff`), and on one resume, logind triggered an immediate poweroff
3. **No hibernate fallback** — zram-only swap (CachyOS default) can't persist across
   power-off, so there was no safety net

### Resume → immediate poweroff (boot -3 forensic)

```
01:32:26  Lid closed
01:32:27  PM: suspend entry (s2idle)
  ... 1 hour 29 minutes pass, S0ix residency = 0 ...
03:01:17  Lid opened → resume
03:01:17  HHD: "Waking up from sleep"
03:01:17  PM: suspend exit
03:01:21  WiFi reconnects
03:01:29  logind: "The system will power off now!"  ← 12s after resume
03:01:30  All services killed
```

Root cause: `HandlePowerKey=poweroff` (default — override not deployed). A power-key
event during the resume sequence was interpreted as a shutdown request. Fixed by
deploying `HandlePowerKey=suspend` (base) / `suspend-then-hibernate` (GPD override).

### Custom stack that was removed

The sleep-inhibitor plugin, lid-display-handler.sh, and `LidSwitchIgnoreInhibited=no`
were a three-piece system for "downloads mode" (block suspend, but allow screen off
on lid close). While functional on sam-duomoon, it added complexity:

- 3 QML plugin files
- logind config change (`LidSwitchIgnoreInhibited=no`)
- D-Bus lid-monitoring shell script (fragile, no systemd restart)

The use case is rare enough that `systemd-inhibit --what=sleep sleep infinity &` in a
terminal covers it. The built-in Noctalia KeepAwake (`--what=idle`) covers the more
common "keep screen on" use case.

### Power states reference

**s2idle (working S0ix):** Processes frozen, CPU in deep C-state, ~0.5-2W, RAM in
self-refresh. Resume in ~1-3s. Days of standby.

**s2idle (broken S0ix):** Processes frozen, CPU in shallow C-state, ~5-15W. Resume
in ~1-3s but battery drains in hours.

**Hibernate (S4):** Full RAM written to disk swap, machine powers off (0W). Resume
in ~10-20s (BIOS POST → kernel reads image). Infinite standby.

**Suspend-then-hibernate:** s2idle first (quick resume window), then auto-hibernate
after delay. Best of both worlds — fast resume for short sleeps, zero power for long.

</details>
