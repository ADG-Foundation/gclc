#!/usr/bin/env bash
set -euo pipefail

SRC_DIR="/app-src"
OUT_DIR="/out"
BUILD_DIR="/tmp/pacman-build"

echo ">>> Installing build dependencies..."
pacman -Syu --noconfirm --needed \
  base-devel cmake gcc git qt6-base hicolor-icon-theme sudo

# makepkg cannot run as root; create a non-root builder user
if ! id -u builder >/dev/null 2>&1; then
  useradd -m -s /bin/bash builder
  echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
fi

echo ">>> Preparing source tree and PKGBUILD..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}/src"

# Copy whitelisted sources into builder workspace
cp "${SRC_DIR}/CMakeLists.txt" "${BUILD_DIR}/src/"
if [ -d "${SRC_DIR}/flatpak" ]; then cp -r "${SRC_DIR}/flatpak" "${BUILD_DIR}/src/"; fi
cp -r "${SRC_DIR}/source" "${BUILD_DIR}/src/"

cp -f "${SRC_DIR}/README.md" "${BUILD_DIR}/src/" 2>/dev/null || true
cp -f "${SRC_DIR}/LICENSE.md" "${BUILD_DIR}/src/" 2>/dev/null || true

if [ -f "${SRC_DIR}/manual/gclc_man.pdf" ]; then
  mkdir -p "${BUILD_DIR}/src/manual"
  cp -f "${SRC_DIR}/manual/gclc_man.pdf" "${BUILD_DIR}/src/manual/"
elif [ -f "${SRC_DIR}/source/manual/gclc_man.pdf" ]; then
  mkdir -p "${BUILD_DIR}/src/manual"
  cp -f "${SRC_DIR}/source/manual/gclc_man.pdf" "${BUILD_DIR}/src/manual/"
fi

for dir in samples working_example LaTeX_packages XML_support; do
  if [ -d "${SRC_DIR}/${dir}" ]; then
    cp -r "${SRC_DIR}/${dir}" "${BUILD_DIR}/src/"
  fi
done

# Pacman versions cannot contain hyphens in $pkgver (hyphen is reserved for $pkgrel)
RAW_VER="${APP_VERSION:-2024.1.0}"
CLEAN_VER="${RAW_VER#v}"
CLEAN_VER="${CLEAN_VER//-/.}"

sed "s/@PKGVER@/${CLEAN_VER}/g" "${SRC_DIR}/packaging/PKGBUILD.in" > "${BUILD_DIR}/PKGBUILD"

mkdir -p "${BUILD_DIR}/src/source/Utils"
cat <<EOF > "${BUILD_DIR}/src/source/Utils/Version.h"
#pragma once
#define GCLC_VERSION "${CLEAN_VER}"
EOF

chown -R builder:builder "${BUILD_DIR}"

echo ">>> Building package with makepkg..."
cd "${BUILD_DIR}"
sudo -u builder makepkg -f --noconfirm

echo ">>> Copying package to output directory..."
mkdir -p "${OUT_DIR}"
cp *.pkg.tar.zst "${OUT_DIR}/"

if [ -n "${HOST_UID:-}" ] && [ -n "${HOST_GID:-}" ]; then
  chown -hR "${HOST_UID}:${HOST_GID}" "${OUT_DIR}" || true
fi

echo ">>> Build complete! Pacman package(s) located in ${OUT_DIR}"