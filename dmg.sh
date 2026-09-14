#!/bin/bash
set -euo pipefail

# ============================================================
# ClamKeep DMG Creation Script
# ============================================================

APP_NAME="ClamKeep"
VERSION="1.4.0"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
VOLUME_NAME="${APP_NAME}"
STAGING_DIR="build/dmg_staging"
APP_BUNDLE="build/${APP_NAME}.app"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $*"; }

if [ ! -d "${APP_BUNDLE}" ]; then
    echo -e "${RED}[ERROR]${NC} Приложение не найдено. Сначала выполните: make build"
    exit 1
fi

info "Создание DMG..."

rm -f "build/${DMG_NAME}"
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"

cp -R "${APP_BUNDLE}" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

hdiutil create \
    -volname "${VOLUME_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "build/${DMG_NAME}"

rm -rf "${STAGING_DIR}"

echo ""
info "========================================="
info "DMG создан!"
info "  DMG:  build/${DMG_NAME}"
info "========================================="
echo ""

du -sh "build/${DMG_NAME}"
