#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

SRC_DIR="/app-src"
OUT_DIR="/out"
BUILD_DIR="/tmp/gclc-deb-build"
GCLC_SRC_SHADOW="/tmp/gclc-src"

# Standardize version string
# - Strip leading 'v'
# - Replace underscores and git-describe hyphens with dots/pluses for Debian packaging policy
RAW_VER="${APP_VERSION:-dev}"
CLEAN_VER="${RAW_VER#v}"
CLEAN_VER="${CLEAN_VER//_/-}"
# Debian version numbers can only have one hyphen before the debian revision.
# If git describe gave e.g. 2026.08-12-g92498c0, turn it into 2026.08+12.g92498c0
CLEAN_VER="$(echo "${CLEAN_VER}" | sed -E 's/-([0-9]+)-g([0-9a-f]+)/+\1.\2/')"

echo ">>> Target version: ${CLEAN_VER}"

echo ">>> Installing Debian build tools and Qt6 packages..."
apt-get update && apt-get install -y --no-install-recommends \
  qt6-base-dev libqt6opengl6-dev \
  cmake gcc g++ build-essential \
  libgles2-mesa-dev libgl1-mesa-dev libegl1-mesa-dev libglu1-mesa-dev libglfw3-dev \
  libx11-xcb-dev libxrender-dev libxi-dev libxcb-xinerama0 libglx-dev \
  libxkbcommon-dev libxkbcommon-x11-dev libxcb-xkb-dev \
  file dpkg-dev ca-certificates git

echo ">>> Whitelisting project source files..."
rm -rf "${GCLC_SRC_SHADOW}"
mkdir -p "${GCLC_SRC_SHADOW}"

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

# Generate Version.h using the exact same sanitized version
mkdir -p source/Utils
cat <<EOF > source/Utils/Version.h
#pragma once
#define GCLC_VERSION "${CLEAN_VER}"
EOF

echo ">>> 3. Configuring and building GCLC..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

cmake -B "${BUILD_DIR}" -S "${GCLC_SRC_SHADOW}" \
  -DCMAKE_BUILD_TYPE=Release \
  -Dgui=ON \
  -DCPACK_PACKAGE_VERSION="${CLEAN_VER}"

cmake --build "${BUILD_DIR}" --parallel "$(nproc)"

echo ">>> Creating Debian package via CPack..."
cd "${BUILD_DIR}"
cpack -G DEB

mkdir -p "${OUT_DIR}"
cp *.deb "${OUT_DIR}/"

if [ -n "${HOST_UID:-}" ] && [ -n "${HOST_GID:-}" ]; then
  chown -hR "${HOST_UID}:${HOST_GID}" "${OUT_DIR}" || true
fi

echo ">>> Build complete! .deb package(s) located in ${OUT_DIR}"