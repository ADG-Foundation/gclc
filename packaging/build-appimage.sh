#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------
# Prepare build
# ---------------------------------------------------------

# Detect machine architecture
RAW_ARCH="$(uname -m)"
case "${RAW_ARCH}" in
  x86_64)
    ARCH="x86_64"
    ;;
  aarch64|arm64)
    ARCH="aarch64"
    ;;
  *)
    echo "Unsupported architecture: ${RAW_ARCH}" && exit 1
    ;;
esac
export ARCH
echo ">>> Detected target architecture: ${ARCH}"

# Paths inside the container
QT_INSTALL_DIR="/cache/qtStatic-${ARCH}"
GCLC_BUILD_DIR="/cache/gclc-build-${ARCH}"
APPDIR="/tmp/AppDir"
OUT_DIR="/out"
SRC_DIR="/app-src"

echo ">>> Installing build dependencies and tools..."
apt-get update && apt-get install -y --no-install-recommends \
  cmake build-essential pkg-config git ca-certificates perl python3 wget file \
  libgl1-mesa-dev libglx-dev libegl1-mesa-dev libglu1-mesa-dev \
  libfreetype6-dev libfontconfig1-dev fontconfig \
  libx11-dev libx11-xcb-dev libxrender-dev libxi-dev libxext-dev \
  libdrm-dev \
  libxkbcommon-dev libxkbcommon-x11-dev \
  libxcb-cursor-dev libxcb-util-dev libxcb-keysyms1-dev \
  libxcb-image0-dev libxcb-shm0-dev libxcb-sync-dev \
  libxcb-xfixes0-dev libxcb-render-util0-dev libxcb-shape0-dev \
  libxcb-randr0-dev libxcb-xkb-dev libxcb-icccm4-dev libxcb-xinerama0-dev


# ---------------------------------------------------------
# Build Static Qt (or reuse existing cache)
# ---------------------------------------------------------
if [ -f "${QT_INSTALL_DIR}/bin/qt-cmake" ]; then
  echo ">>> [Cache Hit] Found static Qt installation at ${QT_INSTALL_DIR}. Skipping Qt build."
else
  echo ">>> [Cache Miss] Compiling static Qt 6.5.2 for ${ARCH}..."

  QT_TMP_BUILD="/tmp/qt-build"
  rm -rf "${QT_TMP_BUILD}"
  mkdir -p "${QT_TMP_BUILD}"
  cd "${QT_TMP_BUILD}"

  git clone --depth 1 -b 6.5.2 https://github.com/qt/qt5.git qt5
  cd qt5
  ./init-repository --module-subset=qtbase

  mkdir -p qtbase/build && cd qtbase/build
  ../configure -static -release -no-pch -nomake tests -nomake examples \
    -no-icu -no-glib \
    -system-freetype -fontconfig \
    -prefix "${QT_INSTALL_DIR}" \
    -xcb-xlib -- -Wno-dev

  cmake --build . --parallel "$(nproc)"
  cmake --install .

  cd /
  rm -rf "${QT_TMP_BUILD}"
fi


# ---------------------------------------------------------
# Build GCLC and stage into AppDir
# ---------------------------------------------------------
echo ">>> Building GCLC GUI..."
rm -rf "${APPDIR}"
mkdir -p "${APPDIR}/usr"

GCLC_SRC_SHADOW="/tmp/gclc-src"
rm -rf "${GCLC_SRC_SHADOW}"
mkdir -p "${GCLC_SRC_SHADOW}"

echo ">>> Copying project source files..."
cp "${SRC_DIR}/CMakeLists.txt" "${GCLC_SRC_SHADOW}/"
if [ -d "${SRC_DIR}/flatpak" ]; then cp -r "${SRC_DIR}/flatpak" "${GCLC_SRC_SHADOW}/"; fi
cp -r "${SRC_DIR}/source" "${GCLC_SRC_SHADOW}/"

# Copy auxiliary files and directories to the shadow root so CMake can install them
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

# Copy sample and support directories
for dir in samples working_example LaTeX_packages XML_support; do
  if [ -d "${SRC_DIR}/${dir}" ]; then
    cp -r "${SRC_DIR}/${dir}" "${GCLC_SRC_SHADOW}/"
  fi
done

cd "${GCLC_SRC_SHADOW}"

# Generate Version.h
RAW_VER="${APP_VERSION:-dev}"
VERSION_STR="$(echo "${RAW_VER}" | sed 's/^v//; s/_/-/g')"
mkdir -p source/Utils
cat <<EOF > source/Utils/Version.h
#pragma once
#define GCLC_VERSION "${VERSION_STR}"
EOF

mkdir -p "${GCLC_BUILD_DIR}"
"${QT_INSTALL_DIR}/bin/qt-cmake" -B "${GCLC_BUILD_DIR}" -S "${GCLC_SRC_SHADOW}" -DCMAKE_BUILD_TYPE=Release
cmake --build "${GCLC_BUILD_DIR}" --parallel "$(nproc)"
cmake --install "${GCLC_BUILD_DIR}" --prefix "${APPDIR}/usr"
rm -f "${APPDIR}/usr/bin/gclc"


# ---------------------------------------------------------
# Package with linuxdeploy into AppImage
# ---------------------------------------------------------
echo ">>> Packaging into AppImage..."
WORKDIR_DEPLOY="/tmp/linuxdeploy"
mkdir -p "${WORKDIR_DEPLOY}" && cd "${WORKDIR_DEPLOY}"

# Download architecture-matching linuxdeploy
wget -q "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-${ARCH}.AppImage"
chmod +x "linuxdeploy-${ARCH}.AppImage"
"./linuxdeploy-${ARCH}.AppImage" --appimage-extract > /dev/null

# Pre-fetch runtime to prevent runner download failure
RUNTIME_FILE="${WORKDIR_DEPLOY}/runtime-${ARCH}"
wget -q -O "${RUNTIME_FILE}" "https://github.com/AppImage/type2-runtime/releases/download/continuous/runtime-${ARCH}"

export APPIMAGE_EXTRACT_AND_RUN=1
export LINUXDEPLOY_OUTPUT_VERSION="${VERSION_STR}"
export VERSION="${VERSION_STR}"
export APPIMAGETOOL_ARGUMENTS="--runtime-file ${RUNTIME_FILE}"

mkdir -p "${OUT_DIR}"
cd "${OUT_DIR}"

"${WORKDIR_DEPLOY}/squashfs-root/AppRun" \
  --appdir "${APPDIR}" \
  --desktop-file "${APPDIR}/usr/share/applications/io.github.ADG_Foundation.gclc.desktop" \
  --executable "${APPDIR}/usr/bin/gclc-gui" \
  --output appimage

# If linuxdeploy created a non-versioned AppImage, rename to ensure consistent naming
if [ -f "GCLC-${ARCH}.AppImage" ]; then
  mv "GCLC-${ARCH}.AppImage" "GCLC-${VERSION_STR}-${ARCH}.AppImage"
fi


# ---------------------------------------------------------
# Cleanup
# ---------------------------------------------------------

# Restore host permissions
if [ -n "${HOST_UID:-}" ] && [ -n "${HOST_GID:-}" ]; then
  chown -hR "${HOST_UID}:${HOST_GID}" "${OUT_DIR}" || true
  if [ -d "/cache" ]; then
    chown -hR "${HOST_UID}:${HOST_GID}" "/cache" || true
  fi
fi

echo ">>> Build complete! AppImage located in ${OUT_DIR}"
