#!/usr/bin/env bash
set -euo pipefail

SRC_DIR="/app-src"
OUT_DIR="/out"
BUILD_DIR="/tmp/gclc-rpm-build"
GCLC_SRC_SHADOW="/tmp/gclc-src"

echo ">>> Installing build dependencies..."
dnf install -y \
    gcc-c++ \
    cmake \
    make \
    rpm-build \
    file \
    qt6-qtbase-devel \
    hicolor-icon-theme \
    libglvnd-devel

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

# Sanitize version string (RPM forbids leading 'v' and hyphens inside the version field)
RAW_VER="${APP_VERSION:-2024.1.0}"
CLEAN_VER="${RAW_VER#v}"        # strip leading 'v'
CLEAN_VER="${CLEAN_VER//-/_}"    # RPM version field prefers underscores or dots over hyphens

mkdir -p source/Utils
cat <<EOF > source/Utils/Version.h
#pragma once
#define GCLC_VERSION "${CLEAN_VER}"
EOF

echo ">>> Configuring and building GCLC..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

cmake -B "${BUILD_DIR}" -S "${GCLC_SRC_SHADOW}" \
  -DCMAKE_BUILD_TYPE=Release \
  -Dgui=ON \
  -DCPACK_PACKAGE_VERSION="${CLEAN_VER}"

cmake --build "${BUILD_DIR}" --parallel "$(nproc)"

echo ">>> Creating RPM package via CPack..."
cd "${BUILD_DIR}"
cpack -G RPM

mkdir -p "${OUT_DIR}"
cp *.rpm "${OUT_DIR}/"

if [ -n "${HOST_UID:-}" ] && [ -n "${HOST_GID:-}" ]; then
  chown -hR "${HOST_UID}:${HOST_GID}" "${OUT_DIR}" || true
fi

echo ">>> Build complete! .rpm package(s) located in ${OUT_DIR}"