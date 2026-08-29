# ClamKeep

macOS menu bar application that keeps your Mac awake when the lid is closed and prevents screen lock when the lid is open.

## Features

- Prevents sleep with closed lid via `pmset disablesleep`
- Prevents screen dimming and lock with open lid via `caffeinate`
- Disables password prompt on screen lock during wake mode
- Minimalist menu bar icon (shield + crescent moon)
- Green accent icon when wake mode is active
- Timer showing wake mode duration
- Launch at login (SMAppService)
- Passwordless operation via privileged helper daemon
- English and Russian interface with language switcher
- No external dependencies
- Universal binary (Apple Silicon + Intel)

## Behavior

| State | Lid Open | Lid Closed |
|-------|----------|------------|
| Wake Mode ON | Screen stays on, no lock, no password | Screen off (hardware), system stays awake |
| Wake Mode OFF | Standard macOS behavior | Standard macOS behavior |

## Installation

### From DMG

1. Download `ClamKeep-1.1.0.dmg` from [Releases](https://github.com/M3etis/ClamKeep/releases)
2. Open the DMG and drag ClamKeep to Applications
3. Launch ClamKeep — on first run, approve the helper daemon installation (one-time password)

### From Source

```bash
git clone https://github.com/M3etis/ClamKeep.git
cd ClamKeep
make build    # Build + install to /Applications
make dmg      # Create DMG installer
```

## Updating the Helper Daemon

When updating ClamKeep, the helper daemon must also be updated:

```bash
sudo cp /Applications/ClamKeep.app/Contents/Resources/clamkeep-helper.sh /usr/local/bin/clamkeep-helper.sh
sudo launchctl bootout system/com.m3etis.clamkeep.helper 2>/dev/null
sudo launchctl bootstrap system /Library/LaunchDaemons/com.m3etis.clamkeep.helper.plist
```

## Usage

1. Click the shield icon in the menu bar to open the menu
2. Select **"Enable Wake Mode"** to prevent sleep — the icon turns green and a timer starts
3. Select **"Disable Wake Mode"** to restore normal sleep behavior
4. Open **Settings** to configure:
   - **Launch at Login** — start ClamKeep automatically on login
   - **Language** — switch between English and Russian
   - **Icon** — choose between Moon, Bolt, Eye, Coffee, or Shield styles
5. Close the lid — your Mac stays awake

## Requirements

- macOS 13.0+
- Xcode Command Line Tools (for building from source)

## Changelog

### 1.1.0
- Added display wake: screen no longer dims or locks with lid open
- Added `caffeinate` integration for active display prevention
- Added screen lock password disable during wake mode
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
