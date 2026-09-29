#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# Paths
SRC_DIR="/app-src"
OUT_DIR="/out"
BUILD_DIR="/tmp/gclc-win-build"
GCLC_SRC_SHADOW="/tmp/gclc-src"
MXE_DIR="/cache/mxe"

echo ">>> Installing build dependencies and NSIS..."
apt-get update && apt-get install -y --no-install-recommends \
  autoconf automake autopoint bash bison build-essential bzip2 flex \
  g++ g++-multilib gettext git gperf intltool iputils-ping libc6-dev-i386 \
  libffi-dev libgdk-pixbuf2.0-dev libltdl-dev libssl-dev libtool-bin \
  libxml-parser-perl lzip make openssl p7zip-full patch perl \
  pkg-config ruby scons sed unzip wget xz-utils libgl-dev \
  python3 python3-mako python3-setuptools python-is-python3 \
  nsis file ca-certificates imagemagick

# ---------------------------------------------------------
# Phase 1: Build or Reuse MXE Qt6 Toolchain
# ---------------------------------------------------------
if [ -f "${MXE_DIR}/usr/bin/x86_64-w64-mingw32.static-cmake" ]; then
  echo ">>> [Cache Hit] Found MXE toolchain at ${MXE_DIR}."
else
  echo ">>> [Cache Miss] Building MXE toolchain (x86_64-w64-mingw32.static qt6-qtbase)..."
  rm -rf "${MXE_DIR}"
  git clone https://github.com/mxe/mxe.git "${MXE_DIR}"
  cd "${MXE_DIR}"
  git checkout 1fba476c
  make MXE_TARGETS=x86_64-w64-mingw32.static -j"$(nproc)" qt6-qtbase
fi

export PATH="${MXE_DIR}/usr/bin:${PATH}"

# ---------------------------------------------------------
# Phase 2: Whitelist sources & Compile Binaries
# ---------------------------------------------------------
echo ">>> Preparing source files..."
rm -rf "${GCLC_SRC_SHADOW}"
mkdir -p "${GCLC_SRC_SHADOW}"

cp "${SRC_DIR}/CMakeLists.txt" "${GCLC_SRC_SHADOW}/"
if [ -d "${SRC_DIR}/flatpak" ]; then cp -r "${SRC_DIR}/flatpak" "${GCLC_SRC_SHADOW}/"; fi
cp -r "${SRC_DIR}/source" "${GCLC_SRC_SHADOW}/"

cd "${GCLC_SRC_SHADOW}"

RAW_VER="${APP_VERSION:-dev}"
CLEAN_VER="${RAW_VER#v}"
CLEAN_VER="${CLEAN_VER//_/-}"

mkdir -p source/Utils
cat <<EOF > source/Utils/Version.h
#pragma once
#define GCLC_VERSION "${CLEAN_VER}"
EOF

convert "${SRC_DIR}/flatpak/icon/32.png" \
        "${SRC_DIR}/flatpak/icon/64.png" \
        "${SRC_DIR}/flatpak/icon/128.png" \
        "${SRC_DIR}/flatpak/icon/256.png" \
        "${GCLC_SRC_SHADOW}/source/app.ico"


echo ">>> 3. Compiling Windows executables with MinGW..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

x86_64-w64-mingw32.static-cmake -B "${BUILD_DIR}" -S "${GCLC_SRC_SHADOW}" \
  -DCMAKE_BUILD_TYPE=Release \
  -Dgui=ON

x86_64-w64-mingw32.static-cmake --build "${BUILD_DIR}" --parallel "$(nproc)"

# ---------------------------------------------------------
# Phase 3: Package Installer with NSIS
# ---------------------------------------------------------
echo ">>> Creating NSIS installer..."
STAGE_DIR="/tmp/gclc-installer-stage"
rm -rf "${STAGE_DIR}"
mkdir -p "${STAGE_DIR}/executable"

# Stage the executables and icon for NSIS
cp "${BUILD_DIR}/gclc.exe" "${STAGE_DIR}/executable/"
cp "${BUILD_DIR}/source/gclc-gui.exe" "${STAGE_DIR}/executable/"
cp "${GCLC_SRC_SHADOW}/source/app.ico" "${STAGE_DIR}/app.ico"
cp "${SRC_DIR}/package/installer.nsi" "${STAGE_DIR}/"

cd "${STAGE_DIR}"
makensis installer.nsi

mkdir -p "${OUT_DIR}"
mv GCLC-Setup.exe "${OUT_DIR}/GCLC-${CLEAN_VER}-Setup.exe"

# Restore permissions for host user
if [ -n "${HOST_UID:-}" ] && [ -n "${HOST_GID:-}" ]; then
  chown -hR "${HOST_UID}:${HOST_GID}" "${OUT_DIR}" || true
  if [ -d "/cache" ]; then
    chown -hR "${HOST_UID}:${HOST_GID}" "/cache" || true
  fi
fi

echo ">>> Build complete! Installer located in ${OUT_DIR}/GCLC-${CLEAN_VER}-Setup.exe"