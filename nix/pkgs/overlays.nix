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
}
