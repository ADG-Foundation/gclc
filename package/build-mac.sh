#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_DIR="${REPO_ROOT}/dist"
BUILD_DIR="${REPO_ROOT}/build-macos"

# Version formatting
RAW_VER="${1:-${APP_VERSION:-dev}}"
CLEAN_VER="${RAW_VER#v}"
CLEAN_VER="${CLEAN_VER//_/-}"

echo ">>> Target version: ${CLEAN_VER}"

# 1. Detect Qt 6 prefix
if command -v brew &>/dev/null; then
  QT6_PREFIX="$(brew --prefix qt@6 2>/dev/null || brew --prefix qt 2>/dev/null || true)"
else
  QT6_PREFIX="${QTDIR:-}"
fi

if [ -z "${QT6_PREFIX}" ] || [ ! -d "${QT6_PREFIX}" ]; then
  echo "Error: Qt6 directory not found. Please install via 'brew install qt@6' or set QTDIR." >&2
  exit 1
fi

echo ">>> Using Qt6 from: ${QT6_PREFIX}"

# 2. Generate Apple .icns from Flatpak PNGs
echo ">>> Generating GCLC.icns..."
ICONSET_DIR="/tmp/GCLC.iconset"
rm -rf "${ICONSET_DIR}"
mkdir -p "${ICONSET_DIR}"

cp "${REPO_ROOT}/flatpak/icon/32.png"  "${ICONSET_DIR}/icon_16x16@2x.png"
cp "${REPO_ROOT}/flatpak/icon/32.png"  "${ICONSET_DIR}/icon_32x32.png"
cp "${REPO_ROOT}/flatpak/icon/64.png"  "${ICONSET_DIR}/icon_32x32@2x.png"
cp "${REPO_ROOT}/flatpak/icon/128.png" "${ICONSET_DIR}/icon_128x128.png"
cp "${REPO_ROOT}/flatpak/icon/256.png" "${ICONSET_DIR}/icon_128x128@2x.png"
cp "${REPO_ROOT}/flatpak/icon/256.png" "${ICONSET_DIR}/icon_256x256.png"
cp "${REPO_ROOT}/flatpak/icon/512.png" "${ICONSET_DIR}/icon_256x256@2x.png"
cp "${REPO_ROOT}/flatpak/icon/512.png" "${ICONSET_DIR}/icon_512x512.png"

mkdir -p "${REPO_ROOT}/source"
iconutil -c icns "${ICONSET_DIR}" -o "${REPO_ROOT}/source/GCLC.icns"
rm -rf "${ICONSET_DIR}"

# 3. Write version header
echo ">>> Setting version in source/Utils/Version.h..."
mkdir -p "${REPO_ROOT}/source/Utils"
cat <<EOF > "${REPO_ROOT}/source/Utils/Version.h"
#pragma once
#define GCLC_VERSION "${CLEAN_VER}"
EOF

# 4. Configure & compile
echo ">>> Building GCLC for macOS..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

cmake -B "${BUILD_DIR}" -S "${REPO_ROOT}" \
  -DCMAKE_BUILD_TYPE=Release \
  -Dgui=ON \
  -DCMAKE_PREFIX_PATH="${QT6_PREFIX}" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="11.0"

cmake --build "${BUILD_DIR}" --parallel "$(sysctl -n hw.ncpu)"

# 5. Locate bundle & deploy DMG
APP_BUNDLE="${BUILD_DIR}/source/gclc-gui.app"
if [ ! -d "${APP_BUNDLE}" ]; then
  APP_BUNDLE="${BUILD_DIR}/gclc-gui.app"
fi

if [ ! -d "${APP_BUNDLE}" ]; then
  echo "Error: Could not find gclc-gui.app in build directory." >&2
  exit 1
fi

echo ">>> Running macdeployqt to produce DMG..."
MACDEPLOYQT="${QT6_PREFIX}/bin/macdeployqt"
if [ ! -f "${MACDEPLOYQT}" ]; then
  echo "Error: macdeployqt not found at ${MACDEPLOYQT}" >&2
  exit 1
fi

# Detect Homebrew lib directory (Apple Silicon vs Intel)
BREW_LIB=""
if command -v brew &>/dev/null; then
  BREW_LIB="$(brew --prefix)/lib"
fi

DEPLOY_FLAGS=("-dmg")
if [ -n "${BREW_LIB}" ] && [ -d "${BREW_LIB}" ]; then
  DEPLOY_FLAGS+=("-libpath=${BREW_LIB}")
fi

"${MACDEPLOYQT}" "${APP_BUNDLE}" "${DEPLOY_FLAGS[@]}"

# Re-sign the app bundle with ad-hoc signing to ensure Gatekeeper integrity
echo ">>> Applying ad-hoc codesign to bundle..."
codesign --force --deep --sign - "${APP_BUNDLE}"

# 6. Collect output
mkdir -p "${DIST_DIR}"
ARCH_NAME="$(uname -m)"
OUTPUT_DMG="${APP_BUNDLE%.app}.dmg"

if [ -f "${OUTPUT_DMG}" ]; then
  mv "${OUTPUT_DMG}" "${DIST_DIR}/GCLC-${CLEAN_VER}-macOS-${ARCH_NAME}.dmg"
  echo ">>> Build complete! Created: ${DIST_DIR}/GCLC-${CLEAN_VER}-macOS-${ARCH_NAME}.dmg"
else
  echo "Warning: .dmg not produced automatically, moving .app bundle instead."
  cp -r "${APP_BUNDLE}" "${DIST_DIR}/"
fi