{
  description = "Sunnypilot Cabana Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    devshell.url = "github:numtide/devshell";
  };

  outputs = inputs@{ flake-parts, devshell, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        devshell.flakeModule
      ];

      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];

      perSystem = { config, self', inputs', pkgs, system, ... }:
        let
          # Python environment with required packages for SCons and build scripts
          pythonEnv = pkgs.python3.withPackages (ps: with ps; [
            numpy
            pycapnp
            pycryptodome
            cython
            setuptools
            cffi
            zstandard
            pyzmq
            requests
            psutil
            tqdm
            smbus2
            sounddevice
            pyserial
            libusb1
            setproctitle
            sympy
            pyjwt
            pillow
            qrcode
            jeepney
            # Add raylib from PyPI
            (buildPythonPackage rec {
              pname = "raylib";
              version = "5.5.0.4";
              format = "wheel";
              src = pkgs.fetchurl {
                url = "https://files.pythonhosted.org/packages/26/6e/09dc5130270d9961b2f2d17f20a92a9c144b0ab40646106c2ef6d3dd2e2e/raylib-5.5.0.4-cp313-cp313-manylinux2014_x86_64.manylinux_2_17_x86_64.whl";
                sha256 = "42c14158f48bf926eaacbc98c3742a9f156a3b52380eeb81fabc2525b2525659";
              };
              doCheck = false;
              nativeBuildInputs = [ pkgs.autoPatchelfHook ];
              buildInputs = with pkgs; [
                libGL
                xorg.libX11
                xorg.libXcursor
                xorg.libXrandr
                xorg.libXinerama
                xorg.libXi
                xorg.libXext
                xorg.libXfixes
                wayland
                libxkbcommon
              ];
              propagatedBuildInputs = [ cffi ];
            })
          ]);

          # Runtime and build libraries
          buildDeps = with pkgs; [
            qt5.qtbase
            qt5.qtcharts
            qt5.qtserialbus
            capnproto
            zeromq
            ffmpeg
            bzip2
            zstd
            curl
            libusb1
            libglvnd
          ];

          # Runtime libraries for Raylib/GLFW
          raylibDeps = with pkgs; [
            libGL
            xorg.libX11
            xorg.libXcursor
            xorg.libXrandr
            xorg.libXinerama
            xorg.libXi
            xorg.libXext
            xorg.libXfixes
            xorg.libXxf86vm
            wayland
            libxkbcommon
          ];

          # Hook to setup environment variables for SCons
          sconsEnvHook = ''
            export QTDIR="${pkgs.qt5.qtbase.dev}"
            export QT_DIR="${pkgs.qt5.qtbase.dev}"
            export PYTHONPATH="${pythonEnv}/${pythonEnv.sitePackages}:$PYTHONPATH"
            
            # Help SCons find headers and libraries that might not be in standard paths
            export CPATH="${pkgs.capnproto}/include:${pkgs.zeromq}/include:${pkgs.libusb1.dev}/include:${pkgs.libusb1.dev}/include/libusb-1.0:${pkgs.libglvnd.dev}/include:${pkgs.qt5.qtserialbus.dev}/include:${pkgs.qt5.qtcharts.dev}/include:${pkgs.ffmpeg.dev}/include:${pkgs.curl.dev}/include:${pkgs.bzip2.dev}/include:${pkgs.zstd.dev}/include:${pkgs.opencl-headers}/include:${pkgs.openssl.dev}/include:${pkgs.zlib.dev}/include:${pkgs.util-linux.dev}/include:${pkgs.ncurses.dev}/include:${pkgs.ncurses.dev}/include/ncurses:${pkgs.ncurses.dev}/include/ncursesw:${pkgs.libyuv}/include:$CPATH"
            export LIBRARY_PATH="${pkgs.capnproto}/lib:${pkgs.zeromq}/lib:${pkgs.libusb1.out}/lib:${pkgs.libglvnd}/lib:${pkgs.qt5.qtserialbus}/lib:${pkgs.qt5.qtcharts}/lib:${pkgs.qt5.qtbase.out}/lib:${pkgs.ffmpeg.lib}/lib:${pkgs.curl.out}/lib:${pkgs.bzip2.out}/lib:${pkgs.zstd.out}/lib:${pkgs.ocl-icd}/lib:${pkgs.openssl.out}/lib:${pkgs.zlib.out}/lib:${pkgs.util-linux.out}/lib:${pkgs.ncurses.out}/lib:${pkgs.libyuv}/lib:$LIBRARY_PATH"
            
            # Runtime library path for Python wheels (raylib)
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath raylibDeps}:$LD_LIBRARY_PATH"
          '';

        in
        {
          devshells.default = {
            name = "sunnypilot-dev";
            
            # Packages available in the shell
            packages = [
              pythonEnv
              pkgs.scons
              pkgs.pkg-config
              pkgs.clang
              pkgs.git
              pkgs.git-lfs
              pkgs.capnproto
              pkgs.qt5.qtbase.dev # For qmake
              pkgs.patchelf
              pkgs.gettext
              pkgs.xvfb-run
            ] ++ buildDeps;

            # Environment variables
            env = [
              { name = "CC"; value = "clang"; }
              { name = "CXX"; value = "clang++"; }
              { name = "QTDIR"; value = "${pkgs.qt5.qtbase.dev}"; }
            ];

            # Commands to show in the welcome message
            commands = [
              {
                name = "build-cabana";
                help = "Build Cabana using SCons";
                command = "scons tools/cabana/";
              }
              {
                name = "init-repos";
                help = "Initialize git submodules";
                command = "git submodule update --init --recursive";
              }
            ];

            # Custom shell hook for detailed setup
            bash.extra = sconsEnvHook;
          };

          packages.cabana = pkgs.stdenv.mkDerivation {
            name = "cabana";
            src = ./.;

            nativeBuildInputs = [
              pythonEnv
              pkgs.scons
              pkgs.pkg-config
              pkgs.capnproto
              pkgs.qt5.wrapQtAppsHook
              pkgs.git
            ];

            buildInputs = buildDeps;

            # Don't try to strip or patch ELF files yet, might break bundled libs
            dontStrip = true;

            buildPhase = ''
              export CC=clang
              export CXX=clang++
              ${sconsEnvHook}
              
              # Run scons with parallel jobs
              scons -j$NIX_BUILD_CORES tools/cabana/
            '';

            installPhase = ''
              mkdir -p $out/bin
              cp tools/cabana/cabana $out/bin/
            '';
          };
        };
    };
}
