# Zenbook Duo Notes

## Detachable Keyboard

**Background**: BT keyboard (device IDs `0x1b2c` USB / `0x1b2d` BT) lacks entries in mainline `hid-asus.c`, so it falls through to `hid-generic`. Basic typing and touchpad work via hid-generic/hid-multitouch.

**DKMS patch**: `hid-asus-zenbook-duo/1.0` is still installed and active (overrides stock hid-asus module). Provides HID descriptor fix, vendor key mapping (MyASUS, Screen Swap), and keyboard backlight support.

**If removing DKMS**: `sudo dkms remove hid-asus-zenbook-duo/1.0 --all` then rebuild initramfs.

**Palm Rejection (DWT) Fix — Two-Part Solution**:
keyd grabs the physical keyboard via `EVIOCGRAB` and re-emits through `keyd virtual keyboard` (uinput). libinput's DWT only pairs internal↔internal devices — both keyboard AND touchpad must be `internal`.

1. **keyd virtual keyboard** → `AttrKeyboardIntegration=internal` via libinput quirks (`etc/libinput/local-overrides.quirks`)
2. **BT touchpad** → `ID_INPUT_TOUCHPAD_INTEGRATION=internal` via udev hwdb (`etc/udev/hwdb.d/71-touchpad-local.hwdb`, match: `touchpad:bluetooth:v0b05p1b2d:*`). Default `70-touchpad.hwdb` tags all BT touchpads as `external`.

**Critical**: `AttrTouchpadIntegration` does NOT exist in libinput — using it causes a parser error that blocks ALL quirks in the file. Only `AttrKeyboardIntegration` (and `AttrPointingStickIntegration`) are valid integration keys. The touchpad integration must be overridden via udev hwdb, not libinput quirks.

Deployed by `arch_setup.sh` gated on hostname `sam-duomoon`. After hwdb changes: `sudo systemd-hwdb update && sudo udevadm trigger /dev/input/eventN`.

## Phantom WMI Media Key Fix (hwdb scancode remapping)

**Issue**: During Slack huddles, mic randomly toggled and volume OSD appeared. ASUS WMI BIOS generates phantom KEY_MICMUTE/KEY_VOLUMEUP/DOWN events during audio activity.

**Root Cause**: `asus-nb-wmi` driver maps WMI notification codes to input keycodes (`0x7c`→MICMUTE, `0x30`→VOLUP, `0x31`→VOLDN, `0x32`→MUTE). keyd `[ids] *` grabs "Asus WMI hotkeys" and passes these phantom events through to niri → wpctl.

**Why keyd split config failed**: The BT keyboard is a composite HID device — three sub-devices share `0b05:1b2d` (keyboard, touchpad, mouse). With `[ids] *`, keyd auto-detects and only grabs keyboards. With explicit `[ids] 0b05:1b2d`, keyd grabs ALL sub-devices including touchpad/mouse, breaking pointer input.

**Fix**: udev hwdb scancode remapping (`etc/udev/hwdb.d/72-asus-wmi-suppress.hwdb`). Remaps the 4 phantom WMI scancodes to `KEY_RESERVED` at the kernel input layer, before any userspace program sees them. keyd stays on `[ids] *` unchanged.

**Key details**:
- Match pattern: `evdev:name:Asus WMI hotkeys:*` (targets only the WMI device by name)
- Physical volume/media keys on BT keyboard use the HID path (`0b05:1b2d`), not WMI — unaffected
- Deployed by `arch_setup.sh` gated on hostname `sam-duomoon` (same block as DWT hwdb)
- Apply: `sudo systemd-hwdb update && sudo udevadm trigger /dev/input/event*`

**Fallback**: If hwdb doesn't suppress events (unlikely), use keyd exclusion syntax: `[ids] *` + `-0000:0000` + `-0000:0006` in default.conf, plus a separate `acpi-block.conf` to grab and noop those devices.

## Pen Jitter Reduction (libinput Tablet Smoothing)

**Issue**: ASUS Pen produces jittery/wobbly lines on both screens.

**Fix**: Explicit `AttrTabletSmoothing=1` quirks for both ELAN digitizers in `etc/libinput/local-overrides.quirks`. This is libinput's default for most tablets, but ELAN integrated digitizers may lack explicit entries.

**Sections**: `[ELAN9008 Stylus Smoothing]` (top screen) and `[ELAN9009 Stylus Smoothing]` (bottom screen). Match on `MatchUdevType=tablet` + `MatchName=ELAN900X:00 ...`.

**Deployment**: Same as DWT quirk — `arch_setup.sh` copies the quirks file to `/etc/libinput/`. Verify with `sudo libinput quirks list /dev/input/eventN`.

**Note**: Pressure sensitivity in Electron/Chromium is broken upstream (Chromium #40282832) — not related to this fix.

## Stylus/Touch Mapping Fix

**Issue**: Niri auto-maps ELAN digitizers to wrong screens (pen on top → bottom, vice versa).

**Fix**: Custom niri build from [PR #1856](https://github.com/niri-wm/niri/pull/1856) (stefanboca fork, branch `sb/push-nrusnuxtqozk`) adds per-device `tablet`/`touch` config. ELAN9008 → eDP-1, ELAN9009 → eDP-2.

**Input Config Architecture** (simplified — niri merges multiple `input {}` blocks):
- Base `input {}` block is inline in `config.kdl` (keyboard, touchpad, mouse, trackpoint)
- `devices/sam-duomoon-inputs.kdl` — device-specific tablet/touch entries with own `input {}` wrapper, committed
- `config.kdl` uses `include optional=true "./device-inputs.kdl"` (skipped on non-Zenbook)
- `stow_dotfiles.sh` copies hostname-matched file → `device-inputs.kdl` (gitignored), same pattern as device-outputs

**First attempt failure**: Building from fork that was 54+ commits behind upstream caused downgrade — broke tablet auto-mapping (pen "half and half", bottom touch stopped). Fix: PKGBUILD `prepare()` now fetches upstream main and rebases PR commits onto it.

**PKGBUILD details**:
- Source: stefanboca fork, `prepare()` rebases onto `upstream/main` before build
- `git -c user.name="build" -c user.email="build@local" rebase upstream/main` — makepkg sandbox lacks git identity
- Cleans leftover rebase/cherry-pick state before rebasing (handles interrupted previous builds)
- `cargo fetch` without `--locked` (lockfile changes after rebase)
- **IgnorePkg**: `niri-git` in `/etc/pacman.conf` on sam-duomoon

**Revert when PR merges**: Restore PKGBUILD source to upstream, remove IgnorePkg, rebuild. Input config architecture stays the same (tablet/touch entries just become no-ops on upstream niri that doesn't support them, or work natively once merged).
