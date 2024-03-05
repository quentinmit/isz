final: prev: {
  multimon-ng = prev.multimon-ng.overrideAttrs (old: {
    buildInputs = with final; old.buildInputs ++ [ libpulseaudio xorg.libX11 ];
  });
  tsduck = prev.tsduck.overrideAttrs (old: {
    meta.broken = false;
    makeFlags = old.makeFlags ++ [
      "CXXFLAGS_WARNINGS=-Wno-error"
    ];
    postPatch = old.postPatch + ''
      substituteInPlace src/utest/Makefile --replace '$(CC)' '$(CXX)'
    '';
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
  itpp = prev.itpp.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      rm VERSION
    '';
    cmakeFlags = if final.stdenv.isDarwin then map (builtins.replaceStrings [".so"] [".dylib"]) old.cmakeFlags else old.cmakeFlags;
    # TODO: Investigate failing test
    doCheck = old.doCheck && !final.stdenv.isDarwin;
    meta.broken = false;
  });
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
      scapy = python-prev.scapy.overrideAttrs (old: {
        patches = (old.patches or []) ++ (lib.optionals stdenv.isDarwin [
          ./scapy/darwin-ioctl.patch
        ]);
      });
      basemap = python-prev.basemap.overrideAttrs (old: {
        CFLAGS = "-Wno-int-conversion -Wno-incompatible-function-pointer-types";
      });
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
    ) old.patches ++ [
    ];
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
  ncftp = prev.ncftp.overrideAttrs (old: {
    # preAutoreconf = ''
    #   #mv configure.in configure.ac
    #   sed -i 's@\(AC_DEFINE_UNQUOTED.PREFIX_BINDIR.*\))@\1, "Define to the full path of $prefix/bin")@' configure.in
    #   #autoupdate
    # '';
    # nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ final.autoreconfHook ];
    patches = (old.patches or []) ++ [
      ./ncftp/patch-configure
    ];
    CC = final.stdenv.cc;
    CFLAGS = "-Wno-implicit-int";
  });
  cdecl = let
    inherit (final) lib stdenv;
  in prev.cdecl.overrideAttrs (old: {
    preBuild = old.preBuild + lib.optionalString stdenv.cc.isClang ''
      makeFlagsArray=(CFLAGS="-DBSD -DUSE_READLINE -std=gnu89 -Wno-int-conversion -Wno-incompatible-function-pointer-types" LIBS=-lreadline);
    '';
  });
  emacs-nox = let
    inherit (final) lib stdenv;
  in prev.emacs-nox.overrideAttrs (old: {
    # https://github.com/NixOS/nixpkgs/pull/253892
    configureFlags = old.configureFlags ++ lib.optionals stdenv.isDarwin [
      "ac_cv_func_aligned_alloc=no"
      "ac_cv_have_decl_aligned_alloc=no"
      "ac_cv_func_posix_spawn_file_actions_addchdir_np=no"
    ];
  });
  wordnet = prev.wordnet.overrideAttrs (old: {
    configureFlags = (old.configureFlags or []) ++ [
      "CFLAGS=-Wno-implicit-int"
    ];
  });
  mdbtools = let
    inherit (final) lib stdenv;
  in prev.mdbtools.overrideAttrs (old: {
    configureFlags = (old.configureFlags or []) ++ lib.optionals stdenv.isDarwin [
      "CFLAGS=-Wno-error=unused-but-set-variable"
    ];
  });
  dsd = let
    inherit (final) lib stdenv;
  in prev.dsd.overrideAttrs (old: {
    CXXFLAGS = (old.CXXFLAGS or "") + " -Wno-error=register";
  });
  pidgin = let
    inherit (final) lib stdenv;
  in prev.pidgin.overrideAttrs (old: {
    CFLAGS = (old.CFLAGS or "") + " -Wno-error=incompatible-function-pointer-types -Wno-error=int-conversion";
  });
  clamav = prev.clamav.override {
    inherit (final.darwin.apple_sdk.frameworks) Foundation;
  };
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
  avrdude = prev.avrdude.override {
    docSupport = !final.stdenv.isDarwin && final.mupdf.meta.available;
  };
}
