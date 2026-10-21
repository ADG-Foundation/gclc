#!/usr/bin/env bash
set -euo pipefail

SRC_DIR="${SRC_DIR:-$(pwd)}"
OUT_DIR="${OUT_DIR:-${SRC_DIR}/dist}"
BUILD_DIR="/tmp/gclc-mac-build"
GCLC_SRC_SHADOW="/tmp/gclc-src"

# Standardize version string
RAW_VER="${APP_VERSION:-dev}"
CLEAN_VER="${RAW_VER#v}"
CLEAN_VER="${CLEAN_VER//_/-}"

echo ">>> Target version: ${CLEAN_VER}"

# Locate Homebrew Qt6 installation
QT_PATH="$(brew --prefix qt@6 2>/dev/null || echo '/usr/local/opt/qt@6')"
if [ ! -d "${QT_PATH}" ]; then
  echo "Error: Qt6 not found at ${QT_PATH}. Please install via 'brew install qt@6'"
  exit 1
fi
echo ">>> Using Qt6 from: ${QT_PATH}"

echo ">>> Preparing source tree..."
rm -rf "${GCLC_SRC_SHADOW}"
mkdir -p "${GCLC_SRC_SHADOW}"

cp "${SRC_DIR}/CMakeLists.txt" "${GCLC_SRC_SHADOW}/"
cp -r "${SRC_DIR}/source" "${GCLC_SRC_SHADOW}/"
cp -f "${SRC_DIR}/README.md" "${GCLC_SRC_SHADOW}/" 2>/dev/null || true
cp -f "${SRC_DIR}/LICENSE.md" "${GCLC_SRC_SHADOW}/" 2>/dev/null || true

# Copy manual PDF if present
if [ -f "${SRC_DIR}/manual/gclc_man.pdf" ]; then
  mkdir -p "${GCLC_SRC_SHADOW}/manual"
  cp -f "${SRC_DIR}/manual/gclc_man.pdf" "${GCLC_SRC_SHADOW}/manual/"
elif [ -f "${SRC_DIR}/source/manual/gclc_man.pdf" ]; then
  mkdir -p "${GCLC_SRC_SHADOW}/manual"
  cp -f "${SRC_DIR}/source/manual/gclc_man.pdf" "${GCLC_SRC_SHADOW}/manual/"
fi

# Copy sample directories
for dir in samples working_example LaTeX_packages XML_support; do
  if [ -d "${SRC_DIR}/${dir}" ]; then
    cp -r "${SRC_DIR}/${dir}" "${GCLC_SRC_SHADOW}/"
  fi
done

cd "${GCLC_SRC_SHADOW}"

# Generate Version.h
mkdir -p source/Utils
cat <<EOF > source/Utils/Version.h
#pragma once
#define GCLC_VERSION "${CLEAN_VER}"
EOF

echo ">>> Configuring and building GCLC for macOS (x86_64)..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

cmake -B "${BUILD_DIR}" -S "${GCLC_SRC_SHADOW}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH="${QT_PATH}" \
  -DCMAKE_OSX_ARCHITECTURES="x86_64" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="11.0" \
  -Dgui=ON \
  -DCPACK_PACKAGE_VERSION="${CLEAN_VER}"

cmake --build "${BUILD_DIR}" --parallel "$(sysctl -n hw.ncpu)"

# Bundle frameworks if a macOS .app bundle is produced by source/
APP_BUNDLE=$(find "${BUILD_DIR}" -maxdepth 3 -name "*.app" -type d | head -n 1)
if [ -n "${APP_BUNDLE}" ]; then
  echo ">>> Bundling Qt libraries into ${APP_BUNDLE}..."
  "${QT_PATH}/bin/macdeployqt" "${APP_BUNDLE}" -always-overwrite || true
fi

echo ">>> Packaging via CPack..."
cd "${BUILD_DIR}"
# Generates DMG image and standard ZIP distribution
cpack -G DragNDrop || cpack -G ZIP

mkdir -p "${OUT_DIR}"
cp -f *.dmg "${OUT_DIR}/" 2>/dev/null || true
cp -f *.zip "${OUT_DIR}/" 2>/dev/null || true

echo ">>> Build complete! Artifacts located in ${OUT_DIR}"