final: prev: {
  esphome = prev.esphome.overrideAttrs (old: {
    meta.platforms = old.meta.platforms ++ final.lib.platforms.darwin;
  });
  esptool_3 = prev.esptool_3.overrideAttrs (old: {
    meta.platforms = old.meta.platforms ++ final.lib.platforms.darwin;
  });
}
