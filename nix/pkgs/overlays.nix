final: prev: {
  alpine = prev.alpine.overrideAttrs (old: if final.stdenv.isDarwin then {
    buildInputs = old.buildInputs ++ [
      final.darwin.apple_sdk.frameworks.Carbon
    ];
    configureFlags = prev.lib.lists.remove "--with-c-client-target=slx" old.configureFlags;
    meta.platforms = old.meta.platforms ++ final.lib.platforms.darwin;
  } else {});
  multimon-ng = prev.multimon-ng.overrideAttrs (old: {
    buildInputs = with final; old.buildInputs ++ [ libpulseaudio xorg.libX11 ];
  });
  xastir = prev.xastir.overrideAttrs (old: {
    meta.platforms = old.meta.platforms ++ final.lib.platforms.darwin;
  });
  esphome = final.unstable.esphome;
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
}
