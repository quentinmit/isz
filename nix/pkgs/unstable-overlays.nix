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
  gqrx-portaudio = (prev.gqrx-portaudio.override {
    inherit (final.libsForQt5) qtbase;
    inherit (final.libsForQt5) qtsvg;
    qtwayland = null;
    alsa-lib = null;
  }).overrideAttrs (old: {
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
  grafana = prev.grafana.overrideAttrs (old: {
    patches = (old.patches or []) ++ [
      (final.fetchpatch2 {
        url = "https://github.com/grafana/grafana/commit/d19a851353adff92b206787226ca262f898901bf.patch";
        hash = "sha256-r0EJTVz5CBBbRQzJ9pihi5MZmF+mPxJcucZ6AjYefSU=";
      })
    ];
  });
}
