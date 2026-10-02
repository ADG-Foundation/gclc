#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

MANUAL_DIR="${REPO_ROOT}/manual"
TEX_ENTRY="${MANUAL_DIR}/gclc_man.tex"

TARGET_MANUAL="${MANUAL_DIR}/gclc_man.pdf"
TARGET_SOURCE="${REPO_ROOT}/source/manual/gclc_man.pdf"

if [ ! -f "${TEX_ENTRY}" ]; then
  echo "Error: ${TEX_ENTRY} not found." >&2
  exit 1
fi

# ---------------------------------------------------------
# 1. Determine if rebuilding the PDF is necessary
# ---------------------------------------------------------
NEEDS_REBUILD=0

if [ ! -f "${TARGET_MANUAL}" ] || [ ! -f "${TARGET_SOURCE}" ]; then
  NEEDS_REBUILD=1
else
  # Check if any .tex file or asset in manual/ is newer than the destination PDF
  NEWEST_TEX=$(find "${MANUAL_DIR}" -type f \( -name "*.tex" -o -name "*.sty" -o -name "*.eps" -o -name "*.png" \) -newer "${TARGET_MANUAL}" | head -n 1)
  if [ -n "${NEWEST_TEX}" ]; then
    echo ">>> Source change detected (${NEWEST_TEX}). Rebuilding manual..."
    NEEDS_REBUILD=1
  fi
fi

if [ "${NEEDS_REBUILD}" -eq 0 ]; then
  echo ">>> Manual is up-to-date. Skipping regeneration."
  exit 0
fi

# ---------------------------------------------------------
# 2. Compile LaTeX inside an isolated /tmp sandbox
# ---------------------------------------------------------
BUILD_TMP="/tmp/gclc-man-build"
rm -rf "${BUILD_TMP}"
mkdir -p "${BUILD_TMP}"

# Copy only the manual source files to tmp so artifacts stay completely isolated
cp -r "${MANUAL_DIR}/." "${BUILD_TMP}/"

echo ">>> Compiling LaTeX manual in isolated directory (${BUILD_TMP})..."

HOST_UID="$(id -u)"
HOST_GID="$(id -g)"

docker run --rm \
  -v "${BUILD_TMP}:/doc" \
  -w /doc \
  -e HOME=/doc \
  -e TEXMFVAR=/doc/.texmf-var \
  -e TEXMFCONFIG=/doc/.texmf-config \
  --user "${HOST_UID}:${HOST_GID}" \
  texlive/texlive:latest \
  sh -c "pdflatex -interaction=batchmode gclc_man.tex && pdflatex -interaction=batchmode gclc_man.tex"

if [ ! -f "${BUILD_TMP}/gclc_man.pdf" ]; then
  echo "Error: PDF generation failed. Check TeX logs." >&2
  # Print tail of log file for quick diagnostics
  [ -f "${BUILD_TMP}/gclc_man.log" ] && tail -n 40 "${BUILD_TMP}/gclc_man.log" >&2
  rm -rf "${BUILD_TMP}"
  exit 1
fi

# ---------------------------------------------------------
# 3. Copy output PDF to destinations and clean up
# ---------------------------------------------------------
mkdir -p "${MANUAL_DIR}"
mkdir -p "${REPO_ROOT}/source/manual"

cp -f "${BUILD_TMP}/gclc_man.pdf" "${TARGET_MANUAL}"
cp -f "${BUILD_TMP}/gclc_man.pdf" "${TARGET_SOURCE}"

# Completely remove all auxiliary .aux, .log, .toc files
rm -rf "${BUILD_TMP}"

echo ">>> Successfully built manual:"
echo "    - ${TARGET_MANUAL}"
echo "    - ${TARGET_SOURCE}"