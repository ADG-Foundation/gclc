MAKEFILE_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
REPO_ROOT    := $(abspath $(MAKEFILE_DIR)/..)

VERSION      ?= $(shell git -C $(REPO_ROOT) describe --tags 2>/dev/null || echo "dev")
CACHE_DIR    ?= $(REPO_ROOT)/.build-cache
OUT_DIR      ?= $(REPO_ROOT)/dist

DOCKER_UBUNTU ?= ubuntu:22.04
DOCKER_FEDORA ?= fedora:latest
DOCKER_ARCH ?= archlinux:latest

HOST_UID := $(shell id -u)
HOST_GID := $(shell id -g)

# Architecture handling (defaults to current host machine)
ARCH ?= $(shell uname -m)

ifeq ($(ARCH),aarch64)
  DOCKER_PLATFORM := linux/arm64
else ifeq ($(ARCH),arm64)
  DOCKER_PLATFORM := linux/arm64
else
  DOCKER_PLATFORM := linux/amd64
endif

.PHONY: help man appimage deb rpm pacman windows clean-cache clean-dist

help:
	@echo "Available packaging targets:"
	@echo "  make man               - Build pdf manual"
	@echo "  make appimage          - Build Linux AppImage"
	@echo "  make deb               - Build Debian (.deb) package"
	@echo "  make rpm               - Build RPM (.rpm) package"
	@echo "  make windows           - Build Windows installer"
	@echo "  make clean-dist        - Remove dist/ directory"
	@echo "  make clean-cache       - Remove .build-cache/ directory"

manual:
	@bash "$(MAKEFILE_DIR)/build-man.sh"

appimage: manual
	@mkdir -p "$(OUT_DIR)" "$(CACHE_DIR)"
	docker run --rm \
	  --platform $(DOCKER_PLATFORM) \
	  -v "$(REPO_ROOT):/app-src:ro" \
	  -v "$(MAKEFILE_DIR)/build-appimage.sh:/build-appimage.sh:ro" \
	  -v "$(OUT_DIR):/out" \
	  -v "$(CACHE_DIR):/cache" \
	  -e APP_VERSION="$(VERSION)" \
	  -e HOST_UID="$(HOST_UID)" \
	  -e HOST_GID="$(HOST_GID)" \
	  $(DOCKER_UBUNTU) /build-appimage.sh

deb: manual
	@mkdir -p "$(OUT_DIR)"
	docker run --rm \
	  --platform $(DOCKER_PLATFORM) \
	  -v "$(REPO_ROOT):/app-src:ro" \
	  -v "$(MAKEFILE_DIR)/build-deb.sh:/build-deb.sh:ro" \
	  -v "$(OUT_DIR):/out" \
	  -e APP_VERSION="$(VERSION)" \
	  -e HOST_UID="$(HOST_UID)" \
	  -e HOST_GID="$(HOST_GID)" \
	  $(DOCKER_UBUNTU) /build-deb.sh

rpm: manual
	@mkdir -p "$(OUT_DIR)"
	docker run --rm \
      --platform $(DOCKER_PLATFORM) \
	  -v "$(REPO_ROOT):/app-src:ro" \
	  -v "$(MAKEFILE_DIR)/build-rpm.sh:/build-rpm.sh:ro" \
	  -v "$(OUT_DIR):/out" \
	  -e APP_VERSION="$(VERSION)" \
	  -e HOST_UID="$(HOST_UID)" \
	  -e HOST_GID="$(HOST_GID)" \
	  $(DOCKER_FEDORA) /build-rpm.sh

pacman: manual
	@mkdir -p "$(OUT_DIR)"
	docker run --rm \
      --platform $(DOCKER_PLATFORM) \
	  -v "$(REPO_ROOT):/app-src:ro" \
	  -v "$(MAKEFILE_DIR)/build-pacman.sh:/build-pacman.sh:ro" \
	  -v "$(OUT_DIR):/out" \
	  -e APP_VERSION="$(VERSION)" \
	  -e HOST_UID="$(HOST_UID)" \
	  -e HOST_GID="$(HOST_GID)" \
	  $(DOCKER_ARCH) /build-pacman.sh

windows: manual
	@mkdir -p "$(OUT_DIR)" "$(CACHE_DIR)"
	docker run --rm \
	  -v "$(REPO_ROOT):/app-src:ro" \
	  -v "$(MAKEFILE_DIR)/build-windows.sh:/build-windows.sh:ro" \
	  -v "$(OUT_DIR):/out" \
	  -v "$(CACHE_DIR):/cache" \
	  -e APP_VERSION="$(VERSION)" \
	  -e HOST_UID="$(HOST_UID)" \
	  -e HOST_GID="$(HOST_GID)" \
	  $(DOCKER_UBUNTU) /build-windows.sh

clean-dist:
	rm -rf "$(OUT_DIR)"

clean-cache:
	rm -rf "$(CACHE_DIR)"