# ClamKeep

macOS menu bar application that keeps your Mac awake with the lid closed. By default the screen stays on and auto-lock waits — you can allow either as an exception while Wake Mode is active.

![ClamKeep features](https://github.com/M3etis/ClamKeep/releases/download/v1.7.0/screenshot.png)

## Features

### Wake Mode
- Keeps your Mac awake with the lid closed — downloads, background tasks, and apps keep running
- By default the screen stays on and auto-lock is delayed
- Green menu-bar icon while active; amber when you allow the display to sleep
- Header shows active modes and either session time or auto-off countdown
- Active toggles are green with **ON** in the shortcut column

### Allow Display Sleep *(exception)*
- Lets the screen turn off while Wake Mode is on (saves battery)
- The Mac itself stays awake
- Default: **off** (screen is held on)

### Allow Auto Lock *(exception)*
- Lets macOS lock the screen after idle while Wake Mode is on
- Default: **off** (auto-lock is delayed)
- **Manual lock** (⌘⌃Q) still locks immediately

### Don't Sleep During Downloads
- Standing policy: while enabled, ClamKeep holds wake when downloads are detected
- Notices download tools and recent/unfinished files in `~/Downloads`
- Does **not** self-disable after one download cycle

### Don't Sleep While Active App…
- Pick a running app; Wake Mode stays on while that app runs
- When the app quits, only the app reason is cleared — other reasons keep wake on

### Auto-off Timer
- Presets **5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60** minutes
- **Custom…** — set hours and minutes
- Header shows **Time left** countdown while the timer is running
- Turning Wake Mode off (manually or when the timer expires) ends the whole session: timer, watchdog, and download policy

### Wake reasons
Wake Mode tracks why it is on: `manual` / `downloads` / `watched app`.
- One reason ending does not cancel the others
- Manual **Wake Mode** off ends the entire keep-awake session

### Settings
- **Launch at Login** (SMAppService)
- **Language** — English, Russian, Kazakh
- **Icon** — Moon, Bolt, Eye, Coffee, Shield
- **About** with repository link
- Passwordless operation after one-time helper install
- Universal binary (Apple Silicon + Intel)

## Behavior

| State | Display | Auto lock | Lid closed |
|-------|---------|-----------|------------|
| Wake Mode (default) | Screen stays on | Delayed | Screen off (hardware), system stays awake |
| + Allow Display Sleep | Display may sleep | Delayed | Screen off (hardware), system stays awake |
| + Allow Auto Lock | Screen stays on (unless also allowed) | Normal after idle; manual lock immediate | Screen off (hardware), system stays awake |
| Wake Mode OFF | Standard macOS | Standard macOS | Standard macOS |
| + Auto-off Timer | Header shows remaining time; session ends at 00:00:00 | | |

Green **ON** on an Allow item means that exception is active.

## Installation

### From DMG

1. Download `ClamKeep-1.7.0.dmg` from [Releases](https://github.com/M3etis/ClamKeep/releases)
2. Open the DMG and drag ClamKeep to Applications
3. Launch ClamKeep — on first run, approve the helper daemon installation (one-time password)

The helper daemon is installed automatically on first launch. When a new version requires a daemon update, ClamKeep will prompt you.

### From Source

```bash
git clone https://github.com/M3etis/ClamKeep.git
cd ClamKeep
make build    # Build + install to /Applications
make dmg      # Create DMG installer
```

## Usage

1. Click the shield icon in the menu bar
2. **Wake Mode** — toggle keep-awake (⌘W). Active items are green with **ON** on the right
3. **Allow Display Sleep** (⌘S) — exception: let the screen turn off while Wake Mode is on
4. **Allow Auto Lock** (⌘L) — exception: let the Mac lock itself after idle
5. **Don't Sleep During Downloads** (⌘D) — hold wake while downloads are detected
6. **Auto-off Timer** — 5…60 min or custom hours/minutes; countdown in the header
7. **Don't Sleep While Active App…** — hold wake while a selected app runs
8. **Settings** — login item, language, icon style
9. **Wake Mode** again ends the session (timer, watchdog, download policy)

## Requirements

- macOS 13.0+
- Xcode Command Line Tools (for building from source)

## Architecture notes

- Menu bar UI: AppKit `NSStatusItem` / `NSMenu`
- Sleep control: root `launchd` helper `clamkeep-helper.sh` → `pmset` (file IPC under `/Library/Application Support/com.m3etis.clamkeep`)
- Display wake: `caffeinate -d -i` while display hold is active (Allow Display Sleep off)
- Auto lock: per-user `askForPasswordDelay` save/restore (no helper change)

## Changelog

### 1.7.0
- Wake Mode now does everything at once: keeps Mac awake, keeps display on, delays auto-lock
- Child options are exceptions: **Allow Display Sleep** / **Allow Auto Lock** (defaults OFF)
- Existing preferences migrate automatically (same effective behavior)
- Menu header chips show hold vs allowed state
- About and docs explain every feature in plain language
- Manual lock (⌘⌃Q) still locks immediately

### 1.6.0
- Wake Mode is a single toggle (**Wake Mode** / **Бодрствование**) instead of Enable/Disable
- **Auto-off Timer**: 5…60 min presets and custom hours/minutes; header shows countdown
- Active options: green title + **ON** in the system shortcut column (stable menu width)
- Turning Wake Mode off ends the session: clears auto-off timer, app watchdog, and download policy
- Header shows only modes that are actually holding the system
- Fixed Custom Timer dialog layout (frame-based accessory)

### 1.5.0
- Added "Prevent Auto Lock" — delays automatic password prompt via `askForPasswordDelay`; manual lock unchanged
- Wake Mode tracks reasons (manual / downloads / app): one source ending no longer cancels the others
- "Don't Sleep During Downloads" is a standing policy (no longer self-disables after one download cycle)
- Download detection: dropped non-specific netstat heuristic; added recent/unfinished files in `~/Downloads`
- `caffeinate` now uses `-d` when Prevent Display Sleep is on (was `-u`)
- Quit now disables wake mode synchronously before terminating
- Stricter helper IPC success check (`ok 0` only)
- Status/About wording accuracy fixes

### 1.4.0
- Added "Don't Sleep During Downloads"
- Renamed "Allow Display Sleep" to "Prevent Display Sleep" with inverted logic
- Renamed "Stay Awake Until..." to "Don't Sleep While Active App..."
- Updated localization strings (EN, RU, KZ)

### 1.3.1
- Fixed IPC permissions after update
- Unified setup flow
- Clearer admin password prompt
- Added Kazakh localization

### 1.3.0
- Removed screen lock override
- `display_enable` no longer sets `askForPassword = 0`
- IPC moved to `/Library/Application Support/com.m3etis.clamkeep`
- Command allowlist + IPC permission hardening

### 1.2.0
- "Allow Display Sleep" option
- "Stay Awake Until..." submenu
- Amber icon for display-sleep-allowed state
- About dialog repository link

### 1.1.0
- Display wake (`caffeinate` + `display_enable` / `display_disable`)
- Updated app icon

### 1.0.0
- Initial release: `pmset disablesleep`, menu bar icon, login item, EN/RU

## Author

m3etis@gmail.com
