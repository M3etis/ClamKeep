# ClamKeep

macOS menu bar application that prevents your Mac from sleeping when the lid is closed.

## Features

- Prevents sleep with closed lid via `pmset disablesleep`
- Minimalist menu bar icon (shield + crescent moon)
- Visual indicator for active/inactive state
- Timer showing wake mode duration
- Launch at login (SMAppService)
- Passwordless operation via privileged helper daemon
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

- Click the shield icon in the menu bar
- Select **"Включить бодрствование"** to enable wake mode
- Select **"Выключить бодрствование"** to disable
- **"Запускать при входе в систему"** — toggle launch at login

## Requirements

- macOS 13.0+
- Xcode Command Line Tools (for building from source)

## Author

m3etis@gmail.com
