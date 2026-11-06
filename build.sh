#!/bin/bash
set -euo pipefail
# All paths below are relative to the repository root.
cd "$(dirname "$0")"

# ============================================================
# ClamKeep Build Script
# ============================================================

APP_NAME="ClamKeep"
BUNDLE_ID="com.m3etis.clamkeep"
VERSION="1.9.0"
BUILD_NUMBER="10"
MIN_MACOS="13.0"

BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

# Every Swift file under Sources/ (including DesignSystem/, MenuBar/, Windows/).
SWIFT_SOURCES=()
while IFS= read -r source; do
    SWIFT_SOURCES+=("$source")
done < <(find Sources -name '*.swift' | sort)

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
# Step 1: App icon (Icon Composer → Assets.car + AppIcon.icns fallback)
# ============================================================
info "Компиляция иконки приложения..."
# actool runs through a long-lived service: pass absolute paths only.
ROOT_DIR="$(pwd)"
xcrun actool "${ROOT_DIR}/Design/AppIcon/AppIcon.icon" \
    --compile "${ROOT_DIR}/${RESOURCES_DIR}" \
    --platform macosx \
    --minimum-deployment-target "${MIN_MACOS}" \
    --app-icon AppIcon \
    --output-partial-info-plist "${ROOT_DIR}/${BUILD_DIR}/icon-partial.plist" \
    --output-format human-readable-text > "${BUILD_DIR}/actool.log" 2>&1 \
    || { cat "${BUILD_DIR}/actool.log"; error "actool не смог собрать иконку"; }
[ -f "${RESOURCES_DIR}/Assets.car" ] || error "Assets.car не создан"

# ============================================================
# Step 2: Info.plist
# ============================================================
info "Создание Info.plist..."
cp Resources/Info.plist "${CONTENTS_DIR}/Info.plist"

# ============================================================
# Step 3: Copy helper files
# ============================================================
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
        -framework SwiftUI \
        -framework ServiceManagement \
        -framework IOKit \
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
# SKIP_INSTALL=1 ./build.sh — build into build/ only, leave /Applications untouched.
if [ "${SKIP_INSTALL:-0}" = "1" ]; then
    info "Сборка готова: ${APP_BUNDLE} (установка пропущена)"
    exit 0
fi

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
