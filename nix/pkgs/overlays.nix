final: prev: let
  inherit (final) lib;
in {
  lesspipe = prev.lesspipe.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      sed -i -e '/html\\\|xml)/,+1d' lesspipe.sh
    '';
  });
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (python-final: python-prev: {
      psychrolib = python-prev.psychrolib.overrideAttrs (old: {
        propagatedBuildInputs = old.propagatedBuildInputs ++ [
          python-final.numba
        ];
      });
      ecdsa = python-prev.ecdsa.overrideAttrs (old: {
        meta = old.meta // {
          # This library is not intended for production use.
          knownVulnerabilities = [];
        };
      });
    })
  ];
  telnet = final.runCommand "telnet" {} ''
    mkdir -p $out/bin $out/share/man/man1
    ln -s ${final.inetutils}/bin/telnet $out/bin/telnet
    ln -s ${final.inetutils}/share/man/man1/telnet.1.gz $out/share/man/man1/telnet.1.gz
  '';
  bashdbInteractive = final.bashdb.overrideAttrs {
    buildInputs = (prev.buildInputs or []) ++ [ final.bashInteractive ];
  };
  gnuplot_gui = if final.stdenv.isDarwin then final.gnuplot else final.gnuplot_qt; # See darwin-overlays.nix
  firewalld = prev.firewalld.overrideAttrs (old: {
    # Patch /usr/lib
    postPatch = ''
      substituteInPlace src/firewall/config/__init__.py.in \
        --replace-fail "/usr/lib/" "/run/current-system/sw/lib/"
    '' + old.postPatch;
  });
  davinci-resolve-studio = prev.davinci-resolve-studio.override (old: {
    buildFHSEnv = a: (old.buildFHSEnv (a // {
      extraBwrapArgs = a.extraBwrapArgs ++ [
        "--bind /run/opengl-driver/etc/OpenCL /etc/OpenCL"
      ];
    }));
  });
  _86Box = prev._86Box.overrideAttrs (old: {
    version = "4.2.1-git";
    src = old.src.override {
      tag = null;
      rev = "714eadfc3a0b3325060cef21f14faa9b90929ec4";
      hash = "sha256-7SbgXxAED5nyrxFBw+EPBb6HjfslWTYsp5TeTQKoenY=";
    };
    passthru = old.passthru // {
      roms = old.passthru.roms.override {
        tag = "v4.2.1";
        rev = null;
      };
    };
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
  yeetgif = prev.yeetgif.overrideAttrs (old: {
    meta = old.meta // {
      # https://github.com/sgreben/yeetgif/tree/1.23.5?tab=readme-ov-file#licensing
      license = with lib.licenses; [ mit asl20 cc-by-40 ];
    };
  });
  mplayer-unfree = let
    codecs = let
      version = "20071007";
      inherit (final) stdenv lib fetchurl;
    in stdenv.mkDerivation {
      pname = "MPlayer-codecs-essential";
      inherit version;

      src = let
        dir = "http://www.mplayerhq.hu/MPlayer/releases/codecs/";
      in
      if stdenv.hostPlatform.system == "i686-linux" then fetchurl {
        url = "${dir}/essential-${version}.tar.bz2";
        sha256 = "18vls12n12rjw0mzw4pkp9vpcfmd1c21rzha19d7zil4hn7fs2ic";
      } else if stdenv.hostPlatform.system == "x86_64-linux" then fetchurl {
        url = "${dir}/essential-amd64-${version}.tar.bz2";
        sha256 = "13xf5b92w1ra5hw00ck151lypbmnylrnznq9hhb0sj36z5wz290x";
      } else if stdenv.hostPlatform.system == "powerpc-linux" then fetchurl {
        url = "${dir}/essential-ppc-${version}.tar.bz2";
        sha256 = "18mlj8dp4wnz42xbhdk1jlz2ygra6fbln9wyrcyvynxh96g1871z";
      } else null;

      installPhase = ''
        mkdir $out
        cp -prv * $out
      '';

      meta.license = lib.licenses.unfree;
    };
  in prev.mplayer.overrideAttrs (old: {
    configureFlags = old.configureFlags ++ [
      "--codecsdir=${codecs}"
    ];
    NIX_CFLAGS_COMPILE = if final.stdenv.cc.isGNU then "-Wno-int-conversion -Wno-incompatible-pointer-types" else old.NIX_CFLAGS_COMPILE;
  });
  povray = prev.povray.overrideAttrs (old: {
    buildInputs = old.buildInputs ++ [
      final.xorg.libXpm
      final.SDL
    ];
  });
  pico-sdk-full = final.pico-sdk.override {
    withSubmodules = true;
  };
  newlib = prev.newlib.overrideAttrs (old: {
    patches = (old.patches or []) ++ [
      ./newlib/fix-texinfo.patch
    ];
  });
  kdePackages = prev.kdePackages.overrideScope (kfinal: kprev: {
    konsole = kprev.konsole.overrideAttrs (old: {
      patches = old.patches or [] ++ [
        ./konsole/no-accel.patch
      ];
    });
  });
  libraw-snapshot = prev.libraw.overrideAttrs (old: {
    version = "0.22-PreRC1";
    src = old.src.override {
      rev = "3733457df9b0420cb90061bceae06adec5aa33c7";
      tag = null;
      hash = "sha256-zGiqpr6/Mls2fa0vCo6rtd5ukL8K8X7u5erHsc6nCpQ=";
    };
  });
  rawtherapee-snapshot = final.rawtherapee.override {
    libraw = final.libraw-snapshot;
  };
  libsigrok = prev.libsigrok.overrideAttrs (old: {
    patches = (old.patches or []) ++ [(final.fetchpatch {
      url = "https://patch-diff.githubusercontent.com/raw/sigrokproject/libsigrok/pull/246.diff";
      hash = "sha256-jIWg3/5woFp4GjXNNoZj6SIn+lWGYrZQXcYGgBqV6sI=";
    })];
  });
  ubootEnvtools = final.ubootTools.override {
    extraMakeFlags = [ "HOST_TOOLS_ALL=y" "CROSS_BUILD_TOOLS=1" "NO_SDL=1" "envtools" ];

    outputs = [ "out" "man" ];

    postInstall = ''
      ln -s $out/bin/fw_printenv $out/bin/fw_setenv
      installManPage doc/*.1
    '';
    filesToInstall = [
      "tools/env/fw_printenv"
    ];
  };
  nbd-static = prev.nbd.overrideAttrs {
    env.NIX_CFLAGS_COMPILE = "-Wno-error=incompatible-pointer-types";
  };
}
