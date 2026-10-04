This directory contains helper scripts to package `gclc` into different packaging formats.
GitHub workflow used for automatically package `gclc` on release uses theese scripts, but they can be run locally as well.

The preferred way to run them is with `make` since `Makefile` contains all the necessary `docker` commands with all the flags needed for successful building and packaging.

You can  run `make` directly from this directory or from the repository root, but in that case you will need to add `-C packaging` argument to it.

Currently, it can package into the following formats:
- AppImage
- Debian package
- RPM package
- Arch Linux package
- Windows installer

Out of thees, the following can be built for arm:
- AppImage
- Debian package
- RPM package

Building for arm can be done with `ARCH=arm64` parameter for `make` or running the `make` on arm machine.


Requirements:
- docker
- make