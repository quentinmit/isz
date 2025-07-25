final: prev: {
  esphome = prev.esphome.overrideAttrs (old: {
    patches = (old.patches or []) ++ [
      ./esphome/object-id-from-id.patch
    ];
    meta.platforms = old.meta.platforms ++ final.lib.platforms.darwin;
  });
  esptool_3 = prev.esptool_3.overrideAttrs (old: {
    meta.platforms = old.meta.platforms ++ final.lib.platforms.darwin;
  });
  gnuradioMinimal = prev.gnuradioMinimal.overrideAttrs (gold: {
    passthru = gold.passthru // {
      pkgs = gold.passthru.pkgs.overrideScope (gself: gsuper: {
        osmosdr = gsuper.osmosdr.overrideAttrs (old: {
          CXXFLAGS = (old.CXXFLAGS or "") + " -Wno-deprecated-register -Wno-register -Wno-unused-parameter";
        });
      });
    };
  });
  vector = prev.vector.overrideAttrs (old: {
    patches = (old.patches or []) ++ [
      ./vector/loki-raw-labels.patch
    ];
  });
  bitmagnet = prev.bitmagnet.overrideAttrs (old: {
    patches = (old.patches or []) ++ [
      ./bitmagnet/tmdb-no-xxx.patch
      ./bitmagnet/http-unix.patch
      ./bitmagnet/persist-files.patch
    ];
  });
}
