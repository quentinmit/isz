final: prev: if prev.stdenv.isDarwin then {
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (python-final: python-prev: with python-final; {
      xdot = python-prev.xdot.overridePythonAttrs {
        # Requires linux-only programs to test.
        doCheck = false;
      };
      scapy = python-prev.scapy.overrideAttrs (old: {
        patches = (old.patches or []) ++ [
          ./scapy/darwin-ioctl.patch
        ];
      });
      basemap = python-prev.basemap.overrideAttrs (old: {
        CFLAGS = "-Wno-int-conversion -Wno-incompatible-function-pointer-types";
      });
    })
  ];
  alpine = prev.alpine.overrideAttrs (old: {
    src = old.src.override {
      rev = "3d6c5540c8c2f4d01331de13e52790e5d7b6ac49";
      hash = "sha256-Y4+SJ+OZw4t51fgF710ijjKt59Fui/SbyQzgNIjVAXU=";
    };
    buildInputs = old.buildInputs ++ [
      final.darwin.apple_sdk.frameworks.Carbon
    ];
    configureFlags = prev.lib.lists.remove "--with-passfile=.pine-passfile" (prev.lib.lists.remove "--with-c-client-target=slx" old.configureFlags);
    meta.platforms = old.meta.platforms ++ final.lib.platforms.darwin;
  });
  xastir = (prev.xastir.overrideAttrs (old: {
    meta.platforms = old.meta.platforms ++ final.lib.platforms.darwin;
  })).override {
    libax25 = null;
  };
  net-snmp = prev.net-snmp.overrideAttrs (old: {
    buildInputs = old.buildInputs ++ (with final.darwin.apple_sdk.frameworks; [
      DiskArbitration
      IOKit
      CoreServices
      ApplicationServices
    ]);
    LIBS = "-framework CoreFoundation -framework CoreServices -framework DiskArbitration -framework IOKit";
    meta.platforms = old.meta.platforms ++ final.lib.platforms.darwin;
  });
  fpc = let
    inherit (final) lib stdenv darwin;
  in prev.fpc.overrideAttrs (old: if (lib.hasInfix "no_uuid" old.postPatch) then {} else {
    # Fixed in https://github.com/NixOS/nixpkgs/commit/a88d4f7dc7ed2d122dcae053863cfa11380f3bfc
    # Needs strip from cctools-port, but ld from cctools-llvm
    prePatch = (old.prePatch or "") + ''
      substituteInPlace fpcsrc/compiler/Makefile{,.fpc} \
        --replace "strip -no_uuid" "${darwin.cctools-port}/bin/strip -no_uuid"
    '';
  });
  motif = let
    inherit (final) fetchpatch;
  in prev.motif.overrideAttrs (old: {
    CFLAGS = "-Wno-incompatible-function-pointer-types -Wno-implicit-function-declaration";
  });
  nbd = let
    inherit (final) lib stdenv;
  in prev.nbd.overrideAttrs (old: {
    configureFlags = (old.configureFlags or []) ++ [
      "CPPFLAGS=-Dfdatasync=fsync"
    ];
  });
  bochs = let
    inherit (final) lib stdenv;
  in prev.bochs.overrideAttrs (old: {
    configureFlags = (old.configureFlags or []) ++ [
      "CXXFLAGS=-fno-aligned-allocation"
    ];
  });
  cdparanoia = let
    inherit (final) lib stdenv;
  in prev.cdparanoia.overrideAttrs (old: {
    configureFlags = (old.configureFlags or []) ++ [
      "CFLAGS=-Wno-implicit-function-declaration"
    ];
  });
  bossa = let
    inherit (final) lib stdenv;
  in prev.bossa.overrideAttrs (old: {
    env = old.env // {
      NIX_CFLAGS_COMPILE = (old.env.NIX_CFLAGS_COMPILE or "") + " -Wno-error=unqualified-std-cast-call";
    };
  });
  xqilla = let
    inherit (final) lib stdenv;
  in prev.xqilla.overrideAttrs (old: {
    configureFlags = (old.configureFlags or []) ++ [
      "CXXFLAGS=-Wno-register"
    ];
    buildInputs = (old.buildInputs or []) ++ [
      final.darwin.apple_sdk.frameworks.CoreFoundation
      final.darwin.apple_sdk.frameworks.CoreServices
      final.darwin.apple_sdk.frameworks.SystemConfiguration
    ];
  });
  ldapvi = let
    inherit (final) fetchpatch;
  in prev.ldapvi.overrideAttrs (old: {
    patches = (old.patches or []) ++ (map (p:
      fetchpatch ({
        url = "https://github.com/macports/macports-ports/raw/1e5b86bebc4dd5a423afc8b4dc2d286ac78cc92f/net/ldapvi/files/${p.name}";
        extraPrefix = "ldapvi/";
      } // p)) [
        {
          name = "patch-ldapvi.patch";
          hash = "sha256-8iO+A4MTz+4AaHkHkMW/5w8beUpnYujmRV5pRuvyFTY=";
        }
        {
          name = "missing-declarations.diff";
          hash = "sha256-zQ25ACwzHgxeNgZhWX6FH4/9EUIDtdeyCohyx7vbJQg=";
        }
      ]);
    meta.platforms = old.meta.platforms ++ final.lib.platforms.darwin;
  });
  gnuplot = prev.gnuplot.override {
    aquaterm = true;
    withCaca = true;
    withLua = true;
    withWxGTK = true;
  };
  tsduck = prev.tsduck.overrideAttrs (old: {
    meta.broken = false;
    makeFlags = old.makeFlags ++ [
      "CXXFLAGS_WARNINGS=-Wno-error"
    ];
    postPatch = old.postPatch + ''
      substituteInPlace src/utest/Makefile --replace '$(CC)' '$(CXX)'
    '';
  });
  itpp = prev.itpp.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      rm VERSION
    '';
    cmakeFlags = map (builtins.replaceStrings [".so"] [".dylib"]) old.cmakeFlags;
    # TODO: Investigate failing test
    doCheck = false;
    meta.broken = false;
  });
  dsd = let
    inherit (final) lib stdenv;
  in prev.dsd.overrideAttrs (old: {
    CXXFLAGS = (old.CXXFLAGS or "") + " -Wno-error=register";
  });
  ncftp = prev.ncftp.overrideAttrs (old: {
    patches = (old.patches or []) ++ [
      ./ncftp/patch-configure
    ];
    CC = final.stdenv.cc;
    CFLAGS = "-Wno-implicit-int";
  });
  cdecl = let
    inherit (final) lib stdenv;
  in if (lib.versionAtLeast prev.cdecl.version "2.5-unstable-2024-05-07") then prev.cdecl else prev.cdecl.overrideAttrs (old: {
    preBuild = old.preBuild + lib.optionalString stdenv.cc.isClang ''
      makeFlagsArray=(CFLAGS="-DBSD -DUSE_READLINE -std=gnu89 -Wno-int-conversion -Wno-incompatible-function-pointer-types" LIBS=-lreadline);
    '';
  });
  emacs-nox = let
    inherit (final) lib stdenv;
  in prev.emacs-nox.overrideAttrs (old: {
    # https://github.com/NixOS/nixpkgs/pull/253892
    configureFlags = old.configureFlags ++ [
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
    configureFlags = (old.configureFlags or []) ++ [
      "CFLAGS=-Wno-error=unused-but-set-variable"
    ];
  });
  pidgin = let
    inherit (final) lib stdenv;
  in prev.pidgin.overrideAttrs (old: {
    CFLAGS = (old.CFLAGS or "") + " -Wno-error=incompatible-function-pointer-types -Wno-error=int-conversion";
  });
  clamav = prev.clamav.override {
    inherit (final.darwin.apple_sdk.frameworks) Foundation;
  };
  ncdu = final.ncdu_1;
  jellycli = (prev.jellycli.override {
    alsa-lib = null;
  }).overrideAttrs (old: {
    patches = [];
    postPatch = ''
      cat >>util/browser_darwin.go <<EOF
      package util

      var browserOpenUrl = "open"
      EOF
    '';
    checkFlags = [
      "-skip"
      "TestInitEmptyConfig|TestAudio_SetVolume"
    ];
    buildInputs = with final; old.buildInputs or [] ++ [
      darwin.apple_sdk.frameworks.AudioToolbox
      darwin.apple_sdk.frameworks.OpenAL
    ];
  });
} else {}
