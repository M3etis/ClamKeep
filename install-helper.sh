#!/bin/bash
# Install ClamKeep helper daemon (requires sudo)
set -euo pipefail

HELPER_SCRIPT="/usr/local/bin/clamkeep-helper.sh"
PLIST_FILE="/Library/LaunchDaemons/com.m3etis.clamkeep.helper.plist"
IPC_DIR="/Library/Application Support/com.m3etis.clamkeep"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC} $*"; }

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR]${NC} Run with sudo: sudo ./install-helper.sh"
    exit 1
fi

info "Installing helper daemon..."

# Stop existing daemon if running
launchctl bootout system/com.m3etis.clamkeep.helper 2>/dev/null || true

# Copy helper script
cp "${SCRIPT_DIR}/clamkeep-helper.sh" "${HELPER_SCRIPT}"
chmod 755 "${HELPER_SCRIPT}"

# Create IPC directory with restricted permissions
mkdir -p "${IPC_DIR}"
chmod 1733 "${IPC_DIR}"

# Create launchd plist with secure logging
cat > "${PLIST_FILE}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.m3etis.clamkeep.helper</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${HELPER_SCRIPT}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/var/log/clamkeep-helper.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/clamkeep-helper.log</string>
</dict>
</plist>
EOF

chmod 644 "${PLIST_FILE}"

# Load daemon
launchctl bootstrap system "${PLIST_FILE}"

info "Daemon installed and started!"
info "To remove: sudo launchctl bootout system/com.m3etis.clamkeep.helper"
