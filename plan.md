# Sunnypilot Cabana Nix Flake Plan

## 1. Goal
Create a reproducible development environment and build definition for `tools/cabana` using **Nix Flakes**, **flake-parts**, and **devshell**.

## 2. Dependencies
Based on `SConstruct` and `tools/cabana/SConscript`, the following dependencies are required:

### Build System & Tools
- **SCons**: Main build system.
- **Python 3**:
  - `numpy`: Required by SConstruct.
  - `pycapnp` (aka `capnp` in pip): Required by `cereal` and DBC generation scripts.
- **Clang**: Compiler (enforced in `SConstruct`).
- **Pkg-Config**: For locating libraries.
- **Git**: For version info and submodule management.
- **Qt5 qmake**: Required by `SConstruct` to query Qt paths.

### Libraries
- **Qt5** (via Nixpkgs):
  - `qtbase` (Core, Gui, Widgets, Network, etc.)
  - `qtcharts`
  - `qtserialbus`
  - *Note*: SCons uses `qmake -query` to find these.
- **Cap'n Proto** (`capnproto`): C++ library and `capnpc` compiler.
- **ZeroMQ** (`zeromq`): Messaging.
- **FFmpeg** (`ffmpeg`): Libs `avcodec`, `avformat`, `avutil`.
- **Compression**: `bzip2`, `zstd`.
- **Network/USB**: `curl`, `libusb1`.
- **Graphics**: `libglvnd` (OpenGL).

### Bundled Dependencies (Pre-built or Source)
The project includes several dependencies in `third_party` (e.g., `libyuv`, `json11`, `acados`). We will rely on these bundled versions to minimize divergence from the upstream build process, ensuring we don't accidentally link against incompatible system versions (especially for `libyuv`).

## 3. Submodules
The build process relies on submodules (`cereal`, `opendbc_repo`, `msgq_repo`, etc.).
**Action Required**: Before building, ensure submodules are initialized:
```bash
git submodule update --init --recursive
```

## 4. Flake Structure
We will use `flake-parts` for the flake structure and `numtide/devshell` for the development environment.

### Inputs
- `nixpkgs`: `nixos-unstable`
- `flake-parts`
- `devshell`

### Outputs
- **`devShells.default`**: A rich shell with all tools in `PATH` and environment variables configured (`QTDIR`, `CPATH`, etc.) to assist SCons.
- **`packages.cabana`**: A derivation that runs the SCons build specifically for the Cabana tool.

## 6. Constraints
- Use `fetchPypi` (or `getpypi` equivalent) for any custom Python package sources; do not fetch tarballs directly from URLs.
- Do not modify original source files.

## 7. Usage
1.  **Initialize Submodules**: `git submodule update --init --recursive`
2.  **Enter Shell**: `nix develop`
3.  **Build**: `scons tools/cabana/`

