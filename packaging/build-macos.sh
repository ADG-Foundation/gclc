#!/usr/bin/env bash
set -euo pipefail

SRC_DIR="${SRC_DIR:-$(pwd)}"
OUT_DIR="${OUT_DIR:-${SRC_DIR}/dist}"
BUILD_DIR="/tmp/gclc-mac-build"
GCLC_SRC_SHADOW="/tmp/gclc-src"

RAW_VER="${APP_VERSION:-dev}"
CLEAN_VER="${RAW_VER#v}"
CLEAN_VER="${CLEAN_VER//_/-}"

echo ">>> Target version: ${CLEAN_VER}"

# Locate Qt6 from aqtinstall QT_DIR or fallback
QT_PATH="${QT_DIR:-$(brew --prefix qt@6 2>/dev/null || echo '/usr/local/opt/qt@6')}"
if [ ! -d "${QT_PATH}" ]; then
  echo "Error: Qt6 directory not found at ${QT_PATH}"
  exit 1
fi
echo ">>> Using Qt6 from: ${QT_PATH}"

echo ">>> Preparing source shadow directory..."
rm -rf "${GCLC_SRC_SHADOW}"
mkdir -p "${GCLC_SRC_SHADOW}"

cp "${SRC_DIR}/CMakeLists.txt" "${GCLC_SRC_SHADOW}/"
cp -r "${SRC_DIR}/source" "${GCLC_SRC_SHADOW}/"
# Ensure the flatpak directory is copied if it exists
if [ -d "${SRC_DIR}/flatpak" ]; then
  cp -r "${SRC_DIR}/flatpak" "${GCLC_SRC_SHADOW}/"
fi
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

for dir in samples working_example LaTeX_packages XML_support; do
  if [ -d "${SRC_DIR}/${dir}" ]; then
    cp -r "${SRC_DIR}/${dir}" "${GCLC_SRC_SHADOW}/"
  fi
done

cd "${GCLC_SRC_SHADOW}"

mkdir -p source/Utils
cat <<EOF > source/Utils/Version.h
#pragma once
#define GCLC_VERSION "${CLEAN_VER}"
EOF

echo ">>> Configuring and building GCLC for macOS (x86_64)..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

cmake -B "${BUILD_DIR}" -S "${GCLC_SRC_SHADOW}" \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH="${QT_PATH}" \
  -DCMAKE_OSX_ARCHITECTURES="x86_64" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="11.0" \
  -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
  -Dgui=ON \
  -DCPACK_PACKAGE_VERSION="${CLEAN_VER}"

cmake --build "${BUILD_DIR}"

echo ">>> Preparing installation directory for packaging..."
INSTALL_STAGING="/tmp/gclc-mac-staging"
rm -rf "${INSTALL_STAGING}"
cmake --install "${BUILD_DIR}" --prefix "${INSTALL_STAGING}"

# Run macdeployqt on the installed staging .app bundle
APP_BUNDLE=$(find "${INSTALL_STAGING}" -maxdepth 3 -name "*.app" -type d | head -n 1)
if [ -n "${APP_BUNDLE}" ]; then
  echo ">>> Bundling Qt dependencies via macdeployqt into ${APP_BUNDLE}..."
  mkdir -p "${APP_BUNDLE}/Contents/Frameworks"
  "${QT_PATH}/bin/macdeployqt" "${APP_BUNDLE}" \
    -always-overwrite \
    -libpath="${QT_PATH}/lib" \
    -verbose=2 || true
fi

echo ">>> Generating installer packages..."
mkdir -p "${OUT_DIR}"

# If an .app bundle exists, package the installed bundle into a DMG or ZIP directly
if [ -n "${APP_BUNDLE}" ]; then
  echo ">>> Creating DMG from installed bundle..."
  hdiutil create -volname "GCLC" -srcfolder "${INSTALL_STAGING}" -ov -format UDZO "${OUT_DIR}/gclc-${CLEAN_VER}-Darwin-x86_64.dmg" || true
  (cd "${INSTALL_STAGING}" && zip -r "${OUT_DIR}/gclc-${CLEAN_VER}-Darwin-x86_64.zip" .)
else
  cd "${BUILD_DIR}"
  cpack -G ZIP
  cp -f *.zip "${OUT_DIR}/" 2>/dev/null || true
fi

echo ">>> Build completed successfully! Packages in ${OUT_DIR}"