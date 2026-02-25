# Tmux Theming Details

## Template Design
- Use `-gq` (quiet) for user variables
- Keep styling in tmux.conf, not in the generated template
- Use `@thm_bg` (surface) for bar background
- **`@thm_on_tertiary` generates correctly** (`#3b2948` dark purple). If colors.conf is missing it, retrigger with: `python3 /etc/xdg/quickshell/noctalia-shell/Scripts/python/src/theming/template-processor.py --scheme ~/.config/noctalia/colors.json --config ~/.config/noctalia/user-templates.toml --mode dark`

## Status Bar Color Assignment (MD3 roles)
- Session icon (prefix off): `@thm_primary` bg + `@thm_on_primary` fg (blue — identity anchor)
- Session icon (prefix on): `@thm_yellow` bg + `@thm_on_yellow` fg (olive gold — warm "mode active" signal)
- Active window: bold `@thm_on_green_container`-colored index + `@thm_green_container` bg pill + `@thm_on_green_container` fg (dark forest green pill, mint text)
- Inactive window: dim `@thm_outline`-colored index outside pill + `@thm_surface` bg + `@thm_text_variant` fg pill
- Dir icon: `@thm_orange` bg + `@thm_on_orange` fg (orange — location)
- Clock icon: `@thm_tertiary` bg + `@thm_on_tertiary` fg (lavender — ambient)
- Dir/clock text: `@thm_fg` fg + `@thm_surface` bg (bright text for readability)

**Color semantics**: olive-gold=prefix active, blue=session identity, dark-forest-green=focused window, orange=location, lavender=clock

## Status Bar Padding
- Use `set -g status 2` + `set -g status-format[1] "#[bg=#{@thm_bg},fill=#{@thm_bg}]"` for empty spacer row below status content.

## Window Pill Shape (Nerd Font rounded separators)
- U+E0B6 (left cap) and U+E0B4 (right cap) stored in `@sep_l`/`@sep_r` user options
- Pill technique: `fg=pill_color bg=status_bg` + left-cap glyph → content → right-cap glyph + same colors
- **Index badge**: Floating index (`#I`) sits BEFORE the left cap. Active: `@thm_secondary` bold. Inactive: `@thm_outline` nobold.
- **AI tool glyph injection**: The Edit tool drops Nerd Font glyphs. Use Python `str.replace()` on just the color-prefix portion to preserve glyphs mid-line.
- **Critical Python escape**: Nerd Font MDI icons are in Supplementary PUA (0xF0000–0xFFFFF). Use `'\U000F0219'` (capital U, 8 digits), NOT `'\uf0219'` (only 4 hex digits).
