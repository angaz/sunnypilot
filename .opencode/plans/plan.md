# Sunnypilot Cabana & Replay Nix Flake Plan

## 1. Goal
Create a reproducible development environment for:
1.  **Cabana**: CAN analysis tool (`tools/cabana`).
2.  **Replay**: Drive replay tool (`tools/replay`).
3.  **UI**: Onroad UI visualization (`selfdrive/ui/ui.py`).

## 2. Dependencies

### Build System & Tools
- **SCons**: Main build system.
- **Python 3**:
  - `numpy`, `cython`, `setuptools`: Build dependencies.
  - `pycapnp`: Messaging.
  - `pycryptodome`: Encryption/Auth.
  - **`raylib`**: Required for `selfdrive/ui/ui.py`.
- **Clang**: Compiler.
- **Git**: Submodules.

### Libraries (System & Build)
- **Qt5**: `qtbase`, `qtcharts`, `qtserialbus`.
- **Cap'n Proto**, **ZeroMQ**.
- **FFmpeg**, **OpenCL** (headers + ICD).
- **Compression**: `bzip2`, `zstd`.
- **Network/USB**: `curl`, `libusb1`.
- **Graphics**: `libglvnd` (OpenGL), `ncurses`.
- **Bundled Replacements**:
  - Link against system `libyuv` to avoid LFS issues.
  - Use system `catch2` headers if bundled ones are missing/LFS-pointers.

## 3. Flake Configuration (`flake.nix`)

### Python Environment
The `ui.py` script requires `raylib` (Python bindings). Since it's not always in standard channels with the required version, fetch it from PyPI.

```nix
pythonEnv = pkgs.python3.withPackages (ps: with ps; [
  numpy
  pycapnp
  pycryptodome
  cython
  setuptools
  # Add raylib from PyPI
  (buildPythonPackage rec {
    pname = "raylib";
    version = "5.5.0.4";
    src = fetchPypi {
      inherit pname version;
      sha256 = "996506e8a533cd7a6a3ef6c44ec11f9d6936698f2c394a991af8022be33079a0";
    };
    doCheck = false;
    propagatedBuildInputs = [ cffi ];
  })
]);
```

### Environment Variables
Export critical paths for SCons to find headers and libraries.
```bash
export CPATH="${pkgs.capnproto}/include:${pkgs.zeromq}/include:${pkgs.libusb1.dev}/include/libusb-1.0:${pkgs.libglvnd.dev}/include:${pkgs.qt5.qtserialbus.dev}/include:${pkgs.qt5.qtcharts.dev}/include:${pkgs.ffmpeg.dev}/include:${pkgs.curl.dev}/include:${pkgs.bzip2.dev}/include:${pkgs.zstd.dev}/include:${pkgs.opencl-headers}/include:${pkgs.openssl.dev}/include:${pkgs.zlib.dev}/include:${pkgs.util-linux.dev}/include:${pkgs.ncurses.dev}/include:${pkgs.ncurses.dev}/include/ncurses:${pkgs.ncurses.dev}/include/ncursesw:${pkgs.libyuv}/include:$CPATH"

export LIBRARY_PATH="${pkgs.capnproto}/lib:${pkgs.zeromq}/lib:${pkgs.libusb1.dev}/lib:${pkgs.libglvnd}/lib:${pkgs.qt5.qtserialbus}/lib:${pkgs.qt5.qtcharts}/lib:${pkgs.qt5.qtbase}/lib:${pkgs.ffmpeg.dev}/lib:${pkgs.curl.out}/lib:${pkgs.bzip2.out}/lib:${pkgs.zstd.out}/lib:${pkgs.ocl-icd}/lib:${pkgs.openssl.out}/lib:${pkgs.zlib.out}/lib:${pkgs.util-linux.out}/lib:${pkgs.ncurses.out}/lib:${pkgs.libyuv}/lib:$LIBRARY_PATH"
```

## 4. Usage Instructions

### Initial Setup
```bash
# Initialize submodules
git submodule update --init --recursive

# Enter Nix Shell
nix develop
```

### Building Tools
```bash
# Build Cabana
scons -j$(nproc) tools/cabana/

# Build Replay
scons -j$(nproc) tools/replay/
```

### Running Replay with UI
Open two terminals in the `nix develop` shell:

**Terminal 1: Replay**
```bash
# Replay demo route
tools/replay/replay --demo
```

**Terminal 2: UI**
```bash
# Launch Onroad UI
# Use BIG=1 for comma 3/3x layout, SCALE=0.5 to resize window
BIG=1 SCALE=0.5 python3 selfdrive/ui/ui.py
```

## 5. Device Settings (Params)
Settings are stored in the "Params" system. You can change them via CLI:

- **Get a setting**: `python3 common/params.py <ParamName>`
- **Set a setting**: `python3 common/params.py <ParamName> <Value>`

**Example**:
```bash
python3 common/params.py ExperimentalMode 1
```

## 6. Constraints
- Use `fetchPypi` for `raylib` python package.
- Do not modify original files where possible (flake handles env).
- Use system `libyuv` to resolve LFS issues with the bundled version.
