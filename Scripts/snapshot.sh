#!/bin/bash
# Dev-only: compile the UI layer with a snapshot harness and render PNGs into build/snapshots.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/snapshots
SOURCES=()
# UI layer only — the AppDelegate extensions need the full app and are skipped.
while IFS= read -r f; do SOURCES+=("$f"); done < <(find Sources/DesignSystem Sources/MenuBar Sources/Windows -name '*.swift' ! -name 'AppDelegate+*' | sort)
swiftc -o build/snapshot-harness \
    "${SOURCES[@]}" Sources/Localizable.swift Sources/SystemMetrics.swift Sources/LoginItem.swift \
    Sources/HelperInstaller.swift Sources/PrivilegedShell.swift \
    Scripts/snapshot/main.swift \
    -framework AppKit -framework SwiftUI -framework IOKit -framework ServiceManagement \
    -target "$(uname -m)-apple-macos13.0" -swift-version 5 -D SNAPSHOT
./build/snapshot-harness build/snapshots
