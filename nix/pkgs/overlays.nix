final: prev: {
  multimon-ng = prev.multimon-ng.overrideAttrs (old: {
    buildInputs = with final; old.buildInputs ++ [ libpulseaudio xorg.libX11 ];
  });
  wireshark-qt5 = (prev.wireshark.overrideAttrs (old: {
    pname = "wireshark-qt5";

    # CMake/Ninja debug:
    #ninjaFlags = (old.ninjaFlags or []) ++ ["-v" "-d" "explain"];
    #NIX_DEBUG = 1;

    cmakeFlags = prev.lib.lists.remove "-DUSE_qt6=ON" old.cmakeFlags ++ [
      "-DCMAKE_BUILD_WITH_INSTALL_NAME_DIR=ON"
      #"-DCMAKE_BUILD_WITH_INSTALL_RPATH=ON"
      #"-DCMAKE_SKIP_INSTALL_RPATH=ON"
    ];
    preFixup = old.preFixup + final.lib.optionalString final.stdenv.isDarwin ''
      # https://bugreports.qt.io/browse/QTBUG-81370
      qtWrapperArgs+=(--set QT_MAC_WANTS_LAYER 1)
      # Remove the executable bit from plugins so that Nix doesn't try to wrap them
      find $out/Applications/Wireshark.app/Contents/PlugIns ! -type d -executable -exec chmod a-x {} \;
    '';
  })).override {
    qt6 = final.qt5 // {
      qt5compat = null;
    };
    stdenv = if final.stdenv.isDarwin then final.darwin.apple_sdk_11_0.stdenv else final.stdenv;
    buildPackages = final.buildPackages // final.lib.optionalAttrs final.stdenv.isDarwin {
      inherit (final.buildPackages.darwin.apple_sdk_11_0) stdenv;
    };
  };
  lesspipe = prev.lesspipe.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      sed -i -e '/html\\\|xml)/,+1d' lesspipe.sh
    '';
  });
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (python-final: python-prev: with python-final; {
      ntc-templates = python-prev.ntc-templates.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          rm $out/lib/*/site-packages/README.md
        '';
      });
      nftables = python-final.buildPythonPackage {
        name = "nftables";
        inherit (final.nftables) src;
        setSourceRoot = "sourceRoot=$(echo */py)";
        postPatch = ''
          substituteInPlace src/nftables.py \
            --replace libnftables.so.1 ${final.nftables}/lib/libnftables.so.1
        '';
        format = "pyproject";
        nativeBuildInputs = [ python-final.setuptools ];
        buildInputs = [ final.nftables ];
      };
    })
  ];
  mesa23_3_0_main = let
    inherit (final) fetchFromGitLab fetchurl lib;
    version = "23.3.0-main";
    hash = "sha256-kHrUNnUedCAc6uOWCHdd/2LMMcz3BAqJPcXnCbHLlaw=";
    branch = lib.versions.major version;
  in prev.mesa.overrideAttrs (old: {
    inherit version;
    src = fetchFromGitLab {
      domain = "gitlab.freedesktop.org";
      owner = "mesa";
      repo = "mesa";
      rev = "4ef573735efc7f15d8b8700622a5865d33c34bf1";
      inherit hash;
    };
    # src = fetchurl {
    #   urls = [
    #     "https://archive.mesa3d.org/mesa-${version}.tar.xz"
    #     "https://mesa.freedesktop.org/archive/mesa-${version}.tar.xz"
    #     "ftp://ftp.freedesktop.org/pub/mesa/mesa-${version}.tar.xz"
    #     "ftp://ftp.freedesktop.org/pub/mesa/${version}/mesa-${version}.tar.xz"
    #     "ftp://ftp.freedesktop.org/pub/mesa/older-versions/${branch}.x/${version}/mesa-${version}.tar.xz"
    #   ];
    #   inherit hash;
    # };
    patches = builtins.filter (
      p: let b = builtins.baseNameOf p; in
         b != "opencl.patch"
         && b != "disk_cache-include-dri-driver-path-in-cache-key.patch"
    ) old.patches;
    mesonFlags =
      (builtins.filter (f: !(lib.hasPrefix "-Ddisk-cache-key=" f)) old.mesonFlags) ++ [
        "-Dgbm=disabled"
        "-Dxlib-lease=disabled"
        "-Degl=disabled"
        "-Dgallium-vdpau=disabled"
        "-Dgallium-va=disabled"
        "-Dgallium-xa=disabled"
        "-Dlmsensors=disabled"
      ];
    meta = old.meta // {
      broken = false;
      platforms = lib.platforms.darwin;
    };
  });
  telnet = final.runCommand "telnet" {} ''
    mkdir -p $out/bin $out/share/man/man1
    ln -s ${final.inetutils}/bin/telnet $out/bin/telnet
    ln -s ${final.inetutils}/share/man/man1/telnet.1.gz $out/share/man/man1/telnet.1.gz
  '';
  bash-preexec = prev.bash-preexec.overrideAttrs (old: {
    # Declare arrays as global variables, so bash-preexec works when loaded within a function.
    installPhase = old.installPhase + ''
      sed -i 's/declare -a/declare -ga/' $out/share/bash/bash-preexec.sh
    '';
  });
  bashdbInteractive = final.bashdb.overrideAttrs {
    buildInputs = (prev.buildInputs or []) ++ [ final.bashInteractive ];
  };
  gobang = prev.gobang.overrideAttrs (old: rec {
    src = old.src.override {
      rev = "refs/pull/177/head";
      hash = "sha256-zoCAl7s5QKNgc5/DChQIKewnFs5P1Y4hm8bakbH//fI=";
    };
    patches = [];
    cargoDeps = old.cargoDeps.overrideAttrs {
      inherit src;
      patches = [];
      cargoPatches = [];
      outputHash = "sha256-xTd/Gw9L/IcgSUT9zGaG85COfkDwS2KLFqrzpRTHyoU=";
    };
  });
  gimpPlugins = prev.gimpPlugins.overrideScope (plugins-final: plugins-prev: {
    gap = if (final.lib.versionAtLeast final.binutils.version "2.41") then plugins-prev.gap.overrideAttrs {
      # https://github.com/NixOS/nixpkgs/issues/294707
      # https://github.com/NixOS/nixpkgs/pull/295257
      postUnpack = ''
        tar -xf $sourceRoot/extern_libs/ffmpeg.tar.gz -C $sourceRoot/extern_libs
      '';

      postPatch = let
        ffmpegPatch = final.fetchpatch2 {
          name = "fix-ffmpeg-binutil-2.41.patch";
          url = "https://git.ffmpeg.org/gitweb/ffmpeg.git/patch/effadce6c756247ea8bae32dc13bb3e6f464f0eb";
          hash = "sha256-vLSltvZVMcQ0CnkU0A29x6fJSywE8/aU+Mp9os8DZYY=";
        };
      in ''
        patch -Np1 -i ${ffmpegPatch} -d extern_libs/ffmpeg
        ffmpegSrc=$(realpath extern_libs/ffmpeg)
      '';

      configureFlags = ["--with-ffmpegsrcdir=${placeholder "ffmpegSrc"}"];
    } else plugins-prev.gap;
  });
  gnuplot_gui = if final.stdenv.isDarwin then final.gnuplot else final.gnuplot_qt; # See darwin-overlays.nix
  firewalld = prev.firewalld.overrideAttrs (old: {
    # Patch /usr/lib, and fix typo in nm-connection-editor
    postPatch = ''
      substituteInPlace src/firewall/config/__init__.py.in \
        --replace "/usr/share" "$out/share" \
        --replace "/usr/lib/" "/run/current-system/sw/lib/"

      for file in config/firewall-{applet,config}.desktop.in; do
        substituteInPlace $file \
          --replace "/usr/bin/" "$out/bin/"
      done
      substituteInPlace src/firewall-applet.in \
        --replace "/usr/bin/nm-connection-editor" "${final.networkmanagerapplet}/bin/nm-connection-editor"
    '';
    # Make NM available for gobject-introspection
    buildInputs = old.buildInputs ++ [final.networkmanager];
    # Fix applet executable
    nativeBuildInputs = old.nativeBuildInputs ++ [final.libsForQt5.wrapQtAppsHook];
    dontWrapQtApps = true;
    preFixup = old.preFixup + ''
      makeWrapperArgs+=("''${qtWrapperArgs[@]}")
    '';
  });
  libsForQt5 = prev.libsForQt5.overrideScope (qt5-final: qt5-prev: {
    krfb = qt5-prev.krfb.overrideAttrs (old: {
      patches = (old.patches or []) ++ [
        ./krfb/krfb-scaling.patch
      ];
    });
  });
  davinci-resolve-studio = prev.davinci-resolve-studio.override (old: {
    buildFHSEnv = a: (old.buildFHSEnv (a // {
      extraBwrapArgs = a.extraBwrapArgs ++ [
        "--bind /run/opengl-driver/etc/OpenCL /etc/OpenCL"
      ];
    }));
  });
  _86Box = prev._86Box.overrideAttrs (old: {
    prePatch = ''
      substituteInPlace src/network/net_pcap.c \
        --replace-fail libpcap.so ${final.libpcap}/lib/libpcap.so
      substituteInPlace src/network/net_vde.c \
        --replace-fail libvdeplug.so ${final.vde2}/lib/libvdeplug.so
      substituteInPlace src/qt/qt_platform.cpp \
        --replace-fail "if (removeSuffixes.contains(fi.suffix())) {" "if (name[0] != '/' && removeSuffixes.contains(fi.suffix())) {"
    '';
#     cmakeFlags = old.cmakeFlags ++ ["-DCMAKE_BUILD_TYPE=RelWithDebInfo"];
#     dontStrip = true;
    buildInputs = old.buildInputs ++ (with final; [
      # Fix mouse capture on Wayland
      extra-cmake-modules
      wayland
      wayland-protocols

      xorg.libXdmcp

      # To make fluidsynth happy
      libevdev
      flac
      libogg
      libvorbis
      libopus
      libmpg123
      libpulseaudio
      libsndfile

      vde2
    ]);
  });
}
