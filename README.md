# ClamKeep

macOS menu bar application that prevents your Mac from sleeping when the lid is closed.

## Features

- Prevents sleep with closed lid via `pmset disablesleep`
- Minimalist menu bar icon (shield + crescent moon)
- Green accent icon when wake mode is active
- Timer showing wake mode duration
- Launch at login (SMAppService)
- Passwordless operation via privileged helper daemon
- English and Russian interface with language switcher
- No external dependencies
- Universal binary (Apple Silicon + Intel)

## Installation

### From DMG

1. Download `ClamKeep-1.0.0.dmg` from [Releases](https://github.com/M3etis/ClamKeep/releases)
2. Open the DMG and drag ClamKeep to Applications
3. Launch ClamKeep — on first run, approve the helper daemon installation (one-time password)

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
3. Select **"Disable Wake Mode"** to restore normal sleep behavior
4. Open **Settings** to configure:
   - **Launch at Login** — start ClamKeep automatically on login
   - **Language** — switch between English and Russian
5. Close the lid — your Mac stays awake

## Requirements

- macOS 13.0+
- Xcode Command Line Tools (for building from source)

## Author

m3etis@gmail.com
