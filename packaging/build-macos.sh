#!/usr/bin/env bash
set -euo pipefail

# ensure running on macOS
if [ "$(uname -s)" != "Darwin" ]; then
  echo "Error: This script must be run on macOS (detected: $(uname -s))." >&2
  exit 1
fi

SRC_DIR="${SRC_DIR:-$(pwd)}"
OUT_DIR="${OUT_DIR:-${SRC_DIR}/dist}"
BUILD_DIR="/tmp/gclc-mac-build"
GCLC_SRC_SHADOW="/tmp/gclc-src"
INSTALL_STAGING="/tmp/gclc-mac-staging"
QT_CACHE_DIR="${QT_CACHE_DIR:-/tmp/Qt}"
QT_VERSION="6.6.3"

RAW_VER="${APP_VERSION:-dev}"
CLEAN_VER="${RAW_VER#v}"
CLEAN_VER="${CLEAN_VER//_/-}"

echo ">>> Target version: ${CLEAN_VER}"

if ! command -v cmake &>/dev/null || ! command -v ninja &>/dev/null; then
  echo ">>> Installing missing build tools (cmake, ninja)..."
  brew install cmake ninja
fi

# install Qt 6.6.3 (clang_64) via aqtinstall
QT_PATH="${QT_DIR:-${QT_CACHE_DIR}/${QT_VERSION}/macos}"
if [ ! -d "${QT_PATH}" ]; then
  echo ">>> Pre-built Qt not found at ${QT_PATH}. Installing via aqtinstall..."
  python3 -m pip install --break-system-packages aqtinstall 2>/dev/null || python3 -m pip install aqtinstall
  python3 -m aqt install-qt mac desktop "${QT_VERSION}" clang_64 --outputdir "${QT_CACHE_DIR}"
fi
echo ">>> Using Qt6 from: ${QT_PATH}"

# Prepare Shadow Source Tree
echo ">>> Preparing source shadow directory..."
rm -rf "${GCLC_SRC_SHADOW}"
mkdir -p "${GCLC_SRC_SHADOW}"

cp "${SRC_DIR}/CMakeLists.txt" "${GCLC_SRC_SHADOW}/"
cp -r "${SRC_DIR}/source" "${GCLC_SRC_SHADOW}/"

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

# Configure & Compile
echo ">>> Configuring and building GCLC..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

cmake -B "${BUILD_DIR}" -S "${GCLC_SRC_SHADOW}" \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH="${QT_PATH}" \
  -DCMAKE_OSX_ARCHITECTURES="x86_64;arm64" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="11.0" \
  -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
  -Dgui=ON \
  -DCPACK_PACKAGE_VERSION="${CLEAN_VER}"

cmake --build "${BUILD_DIR}"

# Staging & App Restructuring
echo ">>> Preparing installation directory for packaging..."
rm -rf "${INSTALL_STAGING}"
cmake --install "${BUILD_DIR}" --prefix "${INSTALL_STAGING}"

# Reposition .app out of bin/ if CMake nested it
if [ -d "${INSTALL_STAGING}/bin/gclc-gui.app" ]; then
  echo ">>> Moving gclc-gui.app from bin/ to bundle root..."
  mv "${INSTALL_STAGING}/bin/gclc-gui.app" "${INSTALL_STAGING}/GCLC.app"
fi

APP_BUNDLE=$(find "${INSTALL_STAGING}" -maxdepth 2 -name "*.app" -type d | head -n 1)

# Verify the .app bundle exists, fail otherwise
if [ -z "${APP_BUNDLE}" ] || [ ! -d "${APP_BUNDLE}" ]; then
  echo "Error: No .app bundle found in ${INSTALL_STAGING}!" >&2
  exit 1
fi

# Deploy Qt Frameworks & Write qt.conf
if [ -n "${APP_BUNDLE}" ]; then
  echo ">>> Bundling Qt dependencies via macdeployqt into ${APP_BUNDLE}..."
  mkdir -p "${APP_BUNDLE}/Contents/Frameworks"
  "${QT_PATH}/bin/macdeployqt" "${APP_BUNDLE}" \
    -always-overwrite \
    -libpath="${QT_PATH}/lib" \
    -verbose=2 || true

  # Ensure qt.conf exists to map plugins and frameworks
  mkdir -p "${APP_BUNDLE}/Contents/Resources"
  cat <<'EOF' > "${APP_BUNDLE}/Contents/Resources/qt.conf"
[Paths]
Prefix = ..
Plugins = PlugIns
Frameworks = Frameworks
EOF
fi

# Package DMG and ZIP
echo ">>> Generating installer packages..."
mkdir -p "${OUT_DIR}"

PACKAGE_FILE_NAME="gclc-${CLEAN_VER}-Darwin"

hdiutil create -volname "GCLC" -srcfolder "${INSTALL_STAGING}" -ov -format UDZO "${OUT_DIR}/${PACKAGE_FILE_NAME}.dmg"

NAMED_DIR="/tmp/${PACKAGE_FILE_NAME}"
rm -rf "${NAMED_DIR}"
mv "${INSTALL_STAGING}" "${NAMED_DIR}"

(cd /tmp && zip -ry "${OUT_DIR}/${PACKAGE_FILE_NAME}.zip" "${PACKAGE_FILE_NAME}")

rm -rf "${NAMED_DIR}"

echo ">>> Build completed successfully! Packages located in ${OUT_DIR}"
