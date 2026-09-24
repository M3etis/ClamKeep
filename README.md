# ClamKeep

[![Version](https://img.shields.io/github/v/release/M3etis/ClamKeep?label=version)](https://github.com/M3etis/ClamKeep/releases/latest)
[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey)](https://github.com/M3etis/ClamKeep#requirements)

macOS menu bar application that keeps your Mac awake with the lid closed. Turning Wake Mode on holds the system, the display, and auto-lock; you can re-enable the last two as exceptions. Turning it off ends the whole session.

![ClamKeep features](https://github.com/M3etis/ClamKeep/releases/download/v1.8.0/screenshot.png)

## Features

### Wake Mode
- Keeps your Mac awake with the lid closed — downloads, background tasks, and apps keep running
- **On enable:** Display Sleep and Auto Lock are automatically forbidden (screen held, auto-lock delayed)
- **On disable:** ends the session and cancels timer, download policy, and watched app
- Menu shows **Wake Mode [ON]** / **[OFF]** — only the status badge is green
- Green menu-bar icon while active; amber when Display Sleep is allowed
- Header shows active modes and either session time or auto-off countdown

### Display Sleep *(exception)*
- Re-enable manually while Wake Mode is on if you want the screen to turn off
- **[ON]** — the screen can turn off (saves battery); the Mac stays awake
- **[OFF]** — screen is held on (default on every new Wake Mode session)
- Shown as **Display Sleep [ON]** / **[OFF]**

### Auto Lock *(exception)*
- Re-enable manually while Wake Mode is on
- **[ON]** — macOS can lock the screen after idle while Wake Mode is on
- **[OFF]** — auto-lock is delayed (default on every new Wake Mode session)
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
- Remaining time survives an app relaunch
- Turning Wake Mode off (manually or when the timer expires) ends the whole session

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

### Security (helper daemon)
- Root `launchd` helper (`clamkeep-helper.sh`) runs a single instance (`lockf`)
- IPC accepts only allowlisted commands (`version/enable/disable/display_* /status`)
- Trigger files must be owned by the UID pinned at install time
- World-writable triggers and shell metacharacters are rejected

## Behavior

| State | Display | Auto lock | Lid closed |
|-------|---------|-----------|------------|
| Wake Mode [ON] (default) | Screen stays on | Delayed | Screen off (hardware), system stays awake |
| + Display Sleep [ON] *(manual exception)* | Display may sleep | Delayed | Screen off (hardware), system stays awake |
| + Auto Lock [ON] *(manual exception)* | Screen stays on (unless Display Sleep also on) | Normal after idle; manual lock immediate | Screen off (hardware), system stays awake |
| Wake Mode [OFF] | Standard macOS | Standard macOS | Standard macOS |
| + Auto-off Timer | Header shows remaining time; session ends at 00:00:00 | | |

Menu items **Wake Mode** / **Display Sleep** / **Auto Lock** show a trailing **[ON]** (green) or **[OFF]** status.

## Installation

### From DMG

1. Download `ClamKeep-1.8.0.dmg` from [Releases](https://github.com/M3etis/ClamKeep/releases)
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
2. **Wake Mode** — toggle keep-awake (⌘W). Status shows **[ON]** / **[OFF]**. Enabling forbids Display Sleep and Auto Lock
3. **Display Sleep** (⌘S) — **[ON]** lets the screen turn off while Wake Mode is on (optional exception)
4. **Auto Lock** (⌘L) — **[ON]** lets the Mac lock itself after idle (optional exception)
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
- Helper IPC is authenticated: single instance, allowlisted commands, trigger owner UID check
- Display wake: `caffeinate -d -i` while display hold is active (Display Sleep [OFF])
- Auto lock: per-user `askForPasswordDelay` save/restore (no helper change)

## Changelog

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
