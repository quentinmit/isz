final: prev: if prev.stdenv.isDarwin then {
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
  mesa_glu = let
    inherit (final) lib stdenv;
  in prev.mesa_glu.overrideAttrs (old: {
    mesonFlags = (old.mesonFlags or []) ++ [
      "-Dgl_provider=gl" # glvnd is default
    ];
  });
  fpc = let
    inherit (final) lib stdenv darwin;
  in prev.fpc.overrideAttrs (old: {
    # Needs strip from cctools-port, but ld from cctools-llvm
    prePatch = (old.prePatch or "") + ''
      substituteInPlace fpcsrc/compiler/Makefile{,.fpc} \
        --replace "strip -no_uuid" "${darwin.cctools-port}/bin/strip -no_uuid"
    '';
  });
  motif = let
    inherit (final) fetchpatch;
  in prev.motif.overrideAttrs (old: {
    patches = old.patches ++ [
      (fetchpatch rec {
        name = "wcs-functions.patch";
        url = "https://github.com/macports/macports-ports/raw/1a671cae6888e36dc95718b2d0b80ae239e289de/x11/openmotif/files/${name}";
        hash = "sha256-w3zCUs/RbnRoUJ0sNCI00noEOkov/IGV/zIygakSQqc=";
        extraPrefix = ""; # Patches are applied with -p1; this gives it a prefix to strip.
      })
    ];
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
} else {}
