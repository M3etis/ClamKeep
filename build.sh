#!/bin/bash
set -euo pipefail

# ============================================================
# ClamKeep Build Script
# ============================================================

APP_NAME="ClamKeep"
BUNDLE_ID="com.m3etis.clamkeep"
VERSION="1.4.0"
BUILD_NUMBER="5"
MIN_MACOS="13.0"

BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

SWIFT_SOURCES=(
    "Sources/main.swift"
    "Sources/AppDelegate.swift"
    "Sources/PrivilegedShell.swift"
    "Sources/LoginItem.swift"
    "Sources/Localizable.swift"
    "Sources/IconRenderer.swift"
    "Sources/AppWatchdog.swift"
)

ENTITLEMENTS_FILE="ClamKeep.entitlements"
SIGN_IDENTITY="-"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ============================================================
# Step 0: Clean
# ============================================================
info "Очистка предыдущей сборки..."
rm -rf "${BUILD_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

# ============================================================
# Step 1: Generate icon if needed
# ============================================================
if [ ! -f "Resources/AppIcon.icns" ]; then
    info "Генерация иконки приложения..."
    ICON_SRC="Resources/icon_1024x1024.png"

    if [ ! -f "${ICON_SRC}" ]; then
        swiftc -o /tmp/gen_icon generate_icon.swift -framework AppKit -target "${ARCHS[0]:-arm64}-apple-macos${MIN_MACOS}" 2>/dev/null
        /tmp/gen_icon "${ICON_SRC}"
    fi

    ICONSET_DIR="Resources/AppIcon.iconset"
    mkdir -p "${ICONSET_DIR}"

    for SIZE_SPEC in \
        "16:icon_16x16.png" \
        "32:icon_16x16@2x.png" \
        "32:icon_32x32.png" \
        "64:icon_32x32@2x.png" \
        "128:icon_128x128.png" \
        "256:icon_128x128@2x.png" \
        "256:icon_256x256.png" \
        "512:icon_256x256@2x.png" \
        "512:icon_512x512.png" \
        "1024:icon_512x512@2x.png"; do
        SIZE="${SIZE_SPEC%%:*}"
        FILENAME="${SIZE_SPEC##*:}"
        sips -z "$SIZE" "$SIZE" "${ICON_SRC}" --out "${ICONSET_DIR}/${FILENAME}" 2>/dev/null
    done

    iconutil -c icns "${ICONSET_DIR}" -o "Resources/AppIcon.icns"
    rm -rf "${ICONSET_DIR}"
fi

# ============================================================
# Step 2: Info.plist
# ============================================================
info "Создание Info.plist..."
cp Resources/Info.plist "${CONTENTS_DIR}/Info.plist"

# ============================================================
# Step 3: Copy icon and helper files
# ============================================================
if [ -f "Resources/AppIcon.icns" ]; then
    cp Resources/AppIcon.icns "${RESOURCES_DIR}/AppIcon.icns"
fi
cp clamkeep-helper.sh "${RESOURCES_DIR}/clamkeep-helper.sh"
cp install-helper.sh "${RESOURCES_DIR}/install-helper.sh"

# ============================================================
# Step 4: Compile
# ============================================================
info "Компиляция Swift..."

ARCHS=("arm64" "x86_64")
OBJECTS=()

for ARCH in "${ARCHS[@]}"; do
    ARCH_DIR="${BUILD_DIR}/${ARCH}"
    mkdir -p "${ARCH_DIR}"

    info "  Компиляция для ${ARCH}..."

    swiftc \
        -o "${ARCH_DIR}/${APP_NAME}" \
        "${SWIFT_SOURCES[@]}" \
        -framework AppKit \
        -framework ServiceManagement \
        -O \
        -whole-module-optimization \
        -target "${ARCH}-apple-macos${MIN_MACOS}" \
        -swift-version 5

    OBJECTS+=("${ARCH_DIR}/${APP_NAME}")
done

# Universal binary
info "Создание универсального бинарника..."
lipo -create "${OBJECTS[@]}" -output "${MACOS_DIR}/${APP_NAME}"

file "${MACOS_DIR}/${APP_NAME}"

# ============================================================
# Step 5: Code signing
# ============================================================
info "Подписание приложения..."
codesign --force --sign "${SIGN_IDENTITY}" \
    --entitlements "${ENTITLEMENTS_FILE}" \
    "${APP_BUNDLE}"

info "Проверка подписи..."
codesign --verify --deep --strict "${APP_BUNDLE}"

info "Удаление карантина..."
xattr -cr "${APP_BUNDLE}"

# ============================================================
# Step 6: Install to /Applications
# ==================================================""
info "Установка в /Applications..."
if [ -d "/Applications/${APP_NAME}.app" ]; then
    rm -rf "/Applications/${APP_NAME}.app"
fi
cp -R "${APP_BUNDLE}" "/Applications/${APP_NAME}.app"
xattr -cr "/Applications/${APP_NAME}.app"

# ============================================================
# Done
# ============================================================
echo ""
info "========================================="
info "Сборка и установка завершены!"
info "  App:  /Applications/${APP_NAME}.app"
info "========================================="
echo ""

du -sh "${APP_BUNDLE}"
du -sh "/Applications/${APP_NAME}.app"
