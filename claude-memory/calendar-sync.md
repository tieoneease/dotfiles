# Google Calendar Sync (khal + vdirsyncer)

## Architecture
- **vdirsyncer**: Syncs Google Calendar via CalDAV (OAuth2) to local `.ics` files
- **khal**: Reads local `.ics` files, provides CLI + Noctalia Shell integration
- **Noctalia**: Auto-detects khal backend — colored dots on dates, event summaries on hover

## GCP Project
- **Owner**: Personal account (`tieoneease@gmail.com`) — portable across machines
- **Project ID**: Dynamic, persisted at `~/.config/vdirsyncer/gcp_project_id` (date-based, e.g. `vdirsyncer-cal-260224`)
- **Old project**: `vdirsyncer-cal-859530` was owned by work account (`sam.chung@peachystudio.com`) — migrated away
- **API**: `caldav.googleapis.com` (NOT `calendar-json.googleapis.com` — vdirsyncer uses CalDAV)
- **OAuth**: Desktop app client, credentials at `~/.config/vdirsyncer/client_id` / `client_secret`
- **Consent screen**: External, testing mode. All sync accounts must be added as test users.
- **gcloud**: `google-cloud-cli` installed via `arch_setup.sh`, used by setup script for project creation

## New Machine Workflow
1. `arch_setup.sh` installs `google-cloud-cli` + `khal` + `vdirsyncer` + stows script
2. Run `setup-google-calendar`
3. `gcloud auth login` → sign into personal account
4. Script detects project already exists → skips creation, ensures CalDAV API enabled
5. Enter Client ID + Secret (same credentials from GCP Console)
6. Add accounts, authorize each in browser → done

## Accounts
- `tieoneease` → tieoneease@gmail.com (3 calendars: primary, Family, US Holidays)
- `chungsam` → chungsam95@gmail.com (1 calendar)
- `work` → sam.chung@peachystudio.com (3 calendars)

## Noctalia Calendar Widget Patches
Applied via `arch_setup.sh` sed patches to `CalendarMonthCard.qml` (re-applied on Noctalia updates):
- **3-dot cap**: `.slice(0, 3)` on `getEventsForDate()` model — busy days (6-7 events) only show 3 dots
- **Dot spacing**: `anchors.bottomMargin: 2` (was `Style.marginXS` = 4px) — pushes dots to cell bottom for more gap from date numbers

## Key Files
- **Stow**: `vdirsyncer/` — systemd timer/service + `setup-google-calendar` script
- **Generated (not stowed)**: `~/.config/vdirsyncer/config`, `~/.config/khal/config`, `~/.config/vdirsyncer/gcp_project_id`
- **Tokens**: `~/.local/share/vdirsyncer/token_{tieoneease,chungsam,work}`
- **Calendar data**: `~/.local/share/calendars/{tieoneease,chungsam,work}/`

## Gotchas
- **CalDAV not Calendar JSON**: vdirsyncer's `google_calendar` type uses CalDAV despite the name. Enable `caldav.googleapis.com`.
- **Test users required**: App in testing mode — each Google account must be added as test user in GCP Audience page.
- **khal default_calendar**: Must match an actual collection name (email address like `tieoneease@gmail.com`), not the label.
- **vdirsyncer discover**: Prompts y/N for each new local collection. Pipe `yes |` to auto-accept.
- **OAuth sign-in**: Each discover pair must auth with the matching Google account. Wrong account → "Not Found" error.
- **GCP project ID**: Must be globally unique. Script generates date-based ID with option to override.

## EDS Removal
Removed `evolution-data-server gnome-online-accounts gnome-control-center` (661MB of GNOME deps). `gnome-control-center` doesn't work outside GNOME — khal+vdirsyncer is the correct approach for niri.

## Sync Schedule
systemd timer: 30s after boot, then every 5 minutes. Noctalia refreshes every 5 minutes.
