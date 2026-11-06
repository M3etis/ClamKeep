# ClamKeep

[![Version](https://img.shields.io/github/v/release/M3etis/ClamKeep?label=version)](https://github.com/M3etis/ClamKeep/releases/latest)
[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey)](https://github.com/M3etis/ClamKeep#requirements)

macOS menu bar application that keeps your Mac awake with the lid closed. Turning Wake Mode on holds the system, the display, and auto-lock; you can re-enable the last two as exceptions. Turning it off ends the whole session. A compact system-stats dashboard sits at the top of the menu.

![ClamKeep features](https://github.com/M3etis/ClamKeep/releases/download/v1.9.0/screenshot.png)

## Features

### System Stats *(new in 1.9)*
- Live metrics at the top of the menu: **Battery · CPU · RAM · Temperature · Fans**
- Each metric is a compact section with an icon, value, and label
- Battery icon reflects charge level; a green tint marks charging
- CPU / RAM / Temp turn orange under load or heat
- Unavailable sensors are hidden automatically (e.g. Fans on fanless Macs)
- Toggle in **Settings… → General → Show System Stats** — applies immediately, no relaunch
- Read via user-space IOKit / AppleSMC (no root, no `powermetrics`)

### Wake Mode
- Keeps your Mac awake with the lid closed — downloads, background tasks, and apps keep running
- **On enable:** Display Sleep and Auto Lock are automatically forbidden (screen held, auto-lock delayed)
- **On disable:** ends the session and cancels timer, download policy, and watched app
- The switch in the menu header (or ⌘W while the menu is open) turns it on and off
- Menu bar icon: outline when off, filled when on, with a small ring when the display may sleep (optionally green / orange — **Settings… → Menu Bar Icon**)
- Header shows either session time or auto-off countdown

### Display Sleep *(exception)*
- Re-enable manually while Wake Mode is on if you want the screen to turn off
- **Allow Display Sleep ✓** — the screen can turn off (saves battery); the Mac stays awake
- Unchecked — screen is held on (default on every new Wake Mode session)

### Auto Lock *(exception)*
- Re-enable manually while Wake Mode is on
- **Allow Auto Lock ✓** — macOS can lock the screen after idle while Wake Mode is on
- Unchecked — auto-lock is delayed (default on every new Wake Mode session)
- **Manual lock** (⌘⌃Q) still locks immediately

### Keep Awake During Downloads
- Standing policy: while enabled, ClamKeep holds wake when downloads are detected
- Notices download tools and recent/unfinished files in `~/Downloads`
- Does **not** self-disable after one download cycle

### Keep Awake While App Runs
- Pick a running app; Wake Mode stays on while that app runs
- When the app quits, only the app reason is cleared — other reasons keep wake on

### Auto-off Timer
- **Turn Off After** presets: **15, 30, 45 min, 1, 2, 4 h**
- **Custom…** — hours and minutes with steppers and a live end time
- Header shows **Time left** countdown while the timer is running
- Remaining time survives an app relaunch
- Turning Wake Mode off (manually or when the timer expires) ends the whole session

### Wake reasons
Wake Mode tracks why it is on: `manual` / `downloads` / `watched app`.
- One reason ending does not cancel the others
- Manual **Wake Mode** off ends the entire keep-awake session

### Settings window (⌘,)
- **General** — Launch at Login (SMAppService), Show System Stats, ask before quitting, language (English, Russian, Kazakh), helper status with install / reinstall
- **Menu Bar Icon** — Lid, Moon, Bolt, Eye, Coffee, Shield, plus “Color the icon while Wake Mode is on”
- **About** — version and links
- Passwordless operation after one-time helper install
- Universal binary (Apple Silicon + Intel)

### Security (helper daemon)
- Root `launchd` helper (`clamkeep-helper.sh`) runs a single instance (`lockf`)
- IPC accepts only allowlisted commands (`version/enable/disable/display_* /status`)
- Trigger files must be owned by the UID pinned at install time
- World-writable triggers and shell metacharacters are rejected

## Behavior

| State | Display | Auto lock | Lid closed |
|-------|---------|-----------|------------|
| Wake Mode on (default) | Screen stays on | Delayed | Screen off (hardware), system stays awake |
| + Allow Display Sleep ✓ *(manual exception)* | Display may sleep | Delayed | Screen off (hardware), system stays awake |
| + Allow Auto Lock ✓ *(manual exception)* | Screen stays on (unless display sleep is also allowed) | Normal after idle; manual lock immediate | Screen off (hardware), system stays awake |
| Wake Mode off | Standard macOS | Standard macOS | Standard macOS |
| + Auto-off Timer | Header shows remaining time; session ends at 00:00:00 | | |

Wake Mode is the switch in the menu header; the two exceptions are checkmark items right below it.

## Installation

### From DMG

1. Download `ClamKeep-1.9.0.dmg` from [Releases](https://github.com/M3etis/ClamKeep/releases)
2. Open the DMG and drag ClamKeep to Applications
3. Launch ClamKeep — the setup window installs the helper daemon (one-time administrator password)

If you close the setup window, the menu header shows an **Install…** banner until the helper is installed. When a new version requires a daemon update, ClamKeep offers it the same way.

### From Source

```bash
git clone https://github.com/M3etis/ClamKeep.git
cd ClamKeep
make build    # Build + install to /Applications
make dmg      # Create DMG installer
SKIP_INSTALL=1 ./build.sh   # Build into build/ only
./Scripts/snapshot.sh       # Render UI previews into build/snapshots
```

## Usage

1. Click the ClamKeep icon in the menu bar
2. Header — Wake Mode status and switch (⌘W), live time, system stats. Turning it on forbids display sleep and auto lock
3. **Allow Display Sleep** (⌘S) — lets the screen turn off while Wake Mode is on (optional exception)
4. **Allow Auto Lock** (⌘L) — lets the Mac lock itself after idle (optional exception)
5. **Keep Awake During Downloads** (⌘D) — hold wake while downloads are detected
6. **Keep Awake While App Runs** — hold wake while a selected app runs
7. **Turn Off After** — 15 min … 4 h or custom; countdown in the header
8. **Settings…** (⌘,) — login item, system stats, language, menu bar icon, helper
9. Switching Wake Mode off ends the session (timer, watchdog, download policy)

## Requirements

- macOS 13.0+
- Building from source: Xcode 26 or later (`actool` compiles the Icon Composer app icon)

## Architecture notes

- Menu bar UI: AppKit `NSStatusItem` / `NSMenu` with a custom status header (`Sources/MenuBar/`)
- Windows: SwiftUI hosted in AppKit windows (`Sources/Windows/`), design tokens and components in `Sources/DesignSystem/`
- App icon: Icon Composer source in `Design/AppIcon/AppIcon.icon` → `Assets.car` + `AppIcon.icns`
- System stats: user-space IOKit (`IOPSCopyPowerSourcesInfo`, `host_processor_info`, `host_statistics64`) + `AppleSMC` for temperature/fans
- Sleep control: root `launchd` helper `clamkeep-helper.sh` → `pmset` (file IPC under `/Library/Application Support/com.m3etis.clamkeep`)
- Helper IPC is authenticated: single instance, allowlisted commands, trigger owner UID check
- Display wake: `caffeinate -d -i` while display hold is active (Allow Display Sleep unchecked)
- Auto lock: per-user `askForPasswordDelay` save/restore (no helper change)

## Changelog

### Unreleased — native redesign
- Status header with the Wake Mode switch, live time, system stats and a helper banner
- Checkmark menu items instead of `[ON]` / `[OFF]` badges; shortcuts unchanged
- Settings window (General, Menu Bar Icon, About), helper setup window, custom timer panel
- Template menu bar icons (new **Lid** style) with an optional color mode
- New app icon with dark, clear and tinted variants
- See `DESIGN_AUDIT.md` and `DESIGN_CHANGELOG.md`

### 1.9.0
- **System Stats dashboard** at the top of the menu: battery, CPU, RAM, temperature, fans (icon + value + label)
- Sensors that are unavailable are hidden automatically
- **Settings → Show System Stats** toggle — applies immediately
- Cleaner menu header: redundant “Active: …” modes line removed

### 1.8.1
- Fixed helper install failing when `/usr/local/bin` did not exist
- Wake Mode stays on after toggling on systems that hit the setup error above

### 1.8.0
- Wake Mode on now **forbids Display Sleep and Auto Lock** automatically; re-enable them manually as exceptions
- Wake Mode off cancels **all** other active options (timer, downloads, watched app, exceptions)
- Fixed: Wake Mode could fail to turn on/off due to helper IPC races and stale command results
- Fixed: auto-off timer now restores the remaining time after relaunch (was reset to full duration)
- Hardened helper daemon (v1.4.0): single instance, authenticated IPC, command allowlist, injection-safe parsing
- UI state updates immediately when toggling Wake Mode

### 1.7.0
- Wake Mode does everything at once: keeps Mac awake, keeps display on, delays auto-lock
- Menu shows **Wake Mode / Display Sleep / Auto Lock** with **[ON]** / **[OFF]** status
- Display Sleep / Auto Lock are exceptions (both **[OFF]** by default)
- Existing preferences migrate automatically
- Manual lock (⌘⌃Q) still locks immediately

### 1.6.0
- Wake Mode is a single toggle (**Wake Mode** / **Бодрствование**)
- **Auto-off Timer**: 5…60 min presets and custom hours/minutes
- Turning Wake Mode off ends the session

## Author

m3etis@gmail.com
