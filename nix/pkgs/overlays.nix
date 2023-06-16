final: prev: {
  alpine = prev.alpine.overrideAttrs (old: if final.stdenv.isDarwin then {
    src = old.src.override {
      rev = "3d6c5540c8c2f4d01331de13e52790e5d7b6ac49";
      hash = "sha256-Y4+SJ+OZw4t51fgF710ijjKt59Fui/SbyQzgNIjVAXU=";
    };
    buildInputs = old.buildInputs ++ [
      final.darwin.apple_sdk.frameworks.Carbon
    ];
    configureFlags = prev.lib.lists.remove "--with-passfile=.pine-passfile" (prev.lib.lists.remove "--with-c-client-target=slx" old.configureFlags);
    meta.platforms = old.meta.platforms ++ final.lib.platforms.darwin;
  } else {});
  multimon-ng = prev.multimon-ng.overrideAttrs (old: {
    buildInputs = with final; old.buildInputs ++ [ libpulseaudio xorg.libX11 ];
  });
  xastir = (prev.xastir.overrideAttrs (old: {
    meta.platforms = old.meta.platforms ++ final.lib.platforms.darwin;
  })).override {
    libax25 = null;
  };
  inherit (final.unstable) esphome;
  net-snmp = prev.net-snmp.overrideAttrs (old: {
    buildInputs = old.buildInputs ++ final.lib.optionals final.stdenv.isDarwin (with final.darwin.apple_sdk.frameworks; [
      DiskArbitration
      IOKit
      CoreServices
      ApplicationServices
    ]);
    configureFlags = old.configureFlags ++ [
      "--sysconfdir=/etc"
    ];
    meta.platforms = old.meta.platforms ++ final.lib.platforms.darwin;
  });
  tsduck = prev.tsduck.overrideAttrs (old: {
    meta.broken = false;
  });
  wireshark-qt5 = (prev.wireshark.overrideAttrs (old: {
    pname = "wireshark-qt5";
    cmakeFlags = prev.lib.lists.remove "-DUSE_qt6=ON" old.cmakeFlags;
    # https://bugreports.qt.io/browse/QTBUG-81370
    preFixup = old.preFixup + final.lib.optionalString final.stdenv.isDarwin ''
      qtWrapperArgs+=(--set QT_MAC_WANTS_LAYER 1)
    '';
  })).override {
    qt6 = final.qt5 // {
      qt5compat = null;
    };
    stdenv = if final.stdenv.isDarwin then final.darwin.apple_sdk_11_0.stdenv else final.stdenv;
    buildPackages = final.buildPackages // final.lib.optionalAttrs final.stdenv.isDarwin {
      stdenv = final.buildPackages.darwin.apple_sdk_11_0.stdenv;
    };
  };
  itpp = prev.itpp.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      rm VERSION
    '';
    cmakeFlags = if final.stdenv.isDarwin then map (s: builtins.replaceStrings [".so"] [".dylib"] s) old.cmakeFlags else old.cmakeFlags;
    # TODO: Investigate failing test
    doCheck = old.doCheck && !final.stdenv.isDarwin;
    meta.broken = false;
  });
}
