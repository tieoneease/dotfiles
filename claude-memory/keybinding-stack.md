# ZMK + keyd + XKB + niri Keybinding Stack

## Full Signal Flow (verified working)

```
ZMK firmware (BLE HID 0xE6 = RightAlt)
  → Linux kernel hid-input (evdev KEY_RIGHTALT = 100)
    → keyd overload(altgr, rightalt) — hold activates [altgr:G] layer
      → unmapped keys fall through with MOD_ALT_GR (emits KEY_RIGHTALT + key)
        → XKB lv3:ralt_switch (KEY_RIGHTALT → ISO_Level3_Shift)
          → niri matches ISO_Level3_Shift+key bindings
```

## Modifier Segregation (current design)

| Modifier | Purpose | keyd layer |
|----------|---------|------------|
| LeftAlt | App shortcuts + numpad digits | `[lower:A]` — `:A` suffix = unmapped keys pass as Alt |
| RightAlt | Workspace control + tab management | `[altgr:G]` — `:G` suffix = unmapped keys pass as AltGr/ISO_Level3_Shift |
| RightAlt+Shift | Column/monitor movement | `[altgr+shift]` — sends `A-S-*` (Alt+Shift) for niri move bindings |
| Both Alts | Vim arrows + Home/End/Scroll + voice (T) | `[lower+altgr]` composite layer |

## Workspace Bindings (niri)

| Binding | Action | Input path |
|---------|--------|------------|
| `ISO_Level3_Shift+1-9` | Focus workspace by number | RightAlt+number → keyd AltGr fallthrough → XKB |
| `ISO_Level3_Shift+Shift+1-9` | Move column to workspace by number | RightAlt+Shift+number |
| `ISO_Level3_Shift+X/C/V/S/D/F/W/E/R` | Focus workspace 1-9 (numpad letters) | RightAlt+letter → keyd AltGr fallthrough |
| `ISO_Level3_Shift+Shift+X/C/V/...` | Move column to workspace 1-9 | RightAlt+Shift+letter |
| `ISO_Level3_Shift+M/Comma` | Focus non-empty workspace up/down | RightAlt+M/, |
| `Alt+P/N` | Focus non-empty workspace up/down | LeftAlt+P/N (ZMK-compatible) |
| `Alt+Shift+P/N` | Move column to workspace up/down | LeftAlt+Shift+P/N |

## Why It Works (keyd internals)

keyd's `MOD_ALT_GR` (0x10) maps to `KEYD_RIGHTALT` (evdev 100) in the `modifiers[]` array in `keys.c`. When `[altgr:G]` is active and a key isn't mapped, `update_mods()` applies `MOD_ALT_GR` → emits `KEY_RIGHTALT` alongside the unmapped key. XKB's `lv3:ralt_switch` intercepts `<RALT>` (evdev 100 + 8 = XKB 108) → `ISO_Level3_Shift`.

## Known Gotcha: Shift+AltGr Ordering

keyd issue #823: `Shift+AltGr+key` may produce different results than `AltGr+Shift+key`. This can affect `ISO_Level3_Shift+Shift+1-9` bindings. If move-to-workspace doesn't work, check modifier press order.

## Ctrl+Number → Tmux Window Switching

`Ctrl+1-9` switches tmux windows directly (no prefix). Requires two-part setup:
- **Kitty**: `map ctrl+N send_text normal,application \x1b[<ascii>;5u` — sends CSI u escape sequences (legacy terminal protocol can't encode Ctrl+number natively). Same pattern as existing Ctrl+Tab/Shift+Tab mappings.
- **Tmux**: `set -g extended-keys on` + `bind -n C-N select-window -t N` — `extended-keys` makes tmux understand CSI u sequences. `base-index 1` + `renumber-windows on` so Ctrl+1 = window 1.
- **Note**: Existing sessions keep 0-based indexing until recreated. New sessions start at 1.

## Super+Number Freed

`Mod+1-9` and `Mod+Ctrl+1-9` removed from niri config. Super+number is now available for app-specific shortcuts or future use.
