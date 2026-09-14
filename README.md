# ClamKeep

macOS menu bar application that keeps your Mac awake when the lid is closed and prevents screen dimming when the lid is open.

## Features

- Prevents sleep with closed lid via `pmset disablesleep`
- Prevents screen dimming with open lid via `caffeinate`
- **Prevent Display Sleep** — keep the screen on while the system stays awake (amber icon when display sleep is allowed)
- **Don't Sleep During Downloads** — automatically enable wake mode when download processes (curl, wget, aria2c) or active network connections are detected
- **Don't Sleep While Active App...** — automatically disable wake mode when a selected app quits
- Minimalist menu bar icon (shield + symbol) with 5 style variants
- Green icon when wake mode is active, amber when display sleep is allowed
- Timer showing wake mode duration
- Launch at login (SMAppService)
- Passwordless operation via privileged helper daemon
- English, Russian, and Kazakh interface with language switcher
- No external dependencies
- Universal binary (Apple Silicon + Intel)

## Behavior

| State | Display | Lid Open | Lid Closed |
|-------|---------|----------|------------|
| Wake Mode ON | Screen stays on | Lock screen works normally | Screen off (hardware), system stays awake |
| Wake Mode ON + Prevent Display Sleep | Screen stays on | Lock screen works normally | System stays awake |
| Wake Mode OFF | Standard macOS | Standard macOS | Standard macOS |

## Installation

### From DMG

1. Download `ClamKeep-1.4.0.dmg` from [Releases](https://github.com/M3etis/ClamKeep/releases)
2. Open the DMG and drag ClamKeep to Applications
3. Launch ClamKeep — on first run, approve the helper daemon installation (one-time password)

The helper daemon is installed automatically on first launch. When a new version requires a daemon update, ClamKeep will prompt you — no manual steps needed.

### From Source

```bash
git clone https://github.com/M3etis/ClamKeep.git
cd ClamKeep
make build    # Build + install to /Applications
make dmg      # Create DMG installer
```

## Usage

1. Click the shield icon in the menu bar to open the menu
2. Select **"Enable Wake Mode"** to prevent sleep — the icon turns green and a timer starts
3. **"Prevent Display Sleep"** — toggle to keep the screen on while the system stays awake (icon turns amber when display sleep is allowed)
4. **"Don't Sleep During Downloads"** — automatically keep the system awake while download processes or active network connections are detected
5. **"Don't Sleep While Active App..."** — pick a running app; wake mode auto-disables when that app quits
6. Open **Settings** to configure:
   - **Launch at Login** — start ClamKeep automatically on login
   - **Language** — switch between English, Russian, and Kazakh
   - **Icon** — choose between Moon, Bolt, Eye, Coffee, or Shield styles
7. Select **"Disable Wake Mode"** to restore normal sleep behavior

## Requirements

- macOS 13.0+
- Xcode Command Line Tools (for building from source)

## Changelog

### 1.4.0
- Added "Don't Sleep During Downloads" — monitors download processes (curl, wget, aria2c) and active network connections, automatically enabling wake mode when downloads are detected
- Renamed "Allow Display Sleep" to "Prevent Display Sleep" with inverted logic for clearer semantics
- Renamed "Stay Awake Until..." to "Don't Sleep While Active App..." for better clarity
- Updated localization strings for all three languages (EN, RU, KZ)

### 1.3.1
- Fixed IPC permissions that prevented Wake Mode from working after update (directory 1731→1733, result file 600→644)
- Unified setup flow: single dialog for both fresh install and daemon update
- System password prompt now shows a clear explanation of why admin privileges are needed
- Added Kazakh localization

### 1.3.0
- Removed screen lock override: Lock Screen (automatic and manual) now works normally during wake mode
- `display_enable` no longer sets `askForPassword = 0`
- Moved IPC directory from `/tmp/clamkeep` to `/Library/Application Support/com.m3etis.clamkeep`
- Added command allowlist validation in helper daemon
- Security hardening: restricted IPC file permissions

### 1.2.0
- Added "Allow Display Sleep" option — system stays awake while screen can turn off
- Added "Stay Awake Until..." submenu — auto-disable wake mode when a selected app quits
- Amber icon color for display-sleep-allowed state
- About dialog now includes repository link

### 1.1.0
- Added display wake: screen no longer dims with lid open
- Added `caffeinate` integration for active display prevention
- Helper daemon now supports `display_enable` / `display_disable` commands
- Updated app icon

### 1.0.0
- Initial release
- Sleep prevention via `pmset disablesleep`
- Menu bar icon with multiple styles
- Launch at login support
- English and Russian localization

## Author

m3etis@gmail.com
