final: prev: let
  inherit (final) lib;
in {
  esphome = prev.esphome.overrideAttrs (old: {
    patches = (old.patches or []) ++ [
      ./esphome/object-id-from-id.patch
    ];
    meta.platforms = old.meta.platforms ++ lib.platforms.darwin;
  });
  esptool_3 = prev.esptool_3.overrideAttrs (old: {
    meta.platforms = old.meta.platforms ++ lib.platforms.darwin;
  });
  # gnuradioMinimal = prev.gnuradioMinimal.overrideAttrs (gold: {
  #   passthru = gold.passthru // {
  #     pkgs = gold.passthru.pkgs.overrideScope (gself: gsuper: {
  #       osmosdr = gsuper.osmosdr.overrideAttrs (old: {
  #         CXXFLAGS = (old.CXXFLAGS or "") + " -Wno-deprecated-register -Wno-register -Wno-unused-parameter";
  #       });
  #     });
  #   };
  # });
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
  # Workarounds for packages that don't support GCC 15 / std=gnu23 yet
  # https://github.com/NixOS/nixpkgs/issues/475479
  rpcemu = prev.rpcemu.overrideAttrs (old: lib.optionalAttrs (!lib.versionOlder "0.9.5" old.version) {
    env = prev.env or {} // {
      NIX_CFLAGS_COMPILE = "-std=gnu17";
    };
  });
  pcem = prev.pcem.overrideAttrs (old: let
    rev = "3a9b8b704b81c77a4e072e27448766b8056b585a";
  in lib.optionalAttrs (!lib.versionOlder "17" old.version) {
    version = "17.${rev}";
    src = final.fetchFromGitHub {
      owner = "sarah-walker-pcem";
      repo = "pcem";
      inherit rev;
      hash = "sha256-FIwgk7yPd3H1rFCHYqeoT9JWEe9cnOzfaPiBYsnSOis=";
    };
    nativeBuildInputs = with final; [
      cmake
      pkg-config
      wrapGAppsHook3
    ];
    buildInputs = old.buildInputs ++ [
      final.libpcap
    ];
    cmakeFlags = [
      (lib.cmakeBool "USE_NETWORKING" true)
      (lib.cmakeBool "USE_PCAP_NETWORKING" true)
      (lib.cmakeBool "USE_ALSA" true)
      (lib.cmakeBool "PLUGIN_ENGINE" true)
      (lib.cmakeBool "I_WANT_TO_USE_GCC" true)
    ];
  });
  gerbv = prev.gerbv.overrideAttrs (old: lib.optionalAttrs (!lib.versionOlder "2.10.0" old.version) {
    env = prev.env or {} // {
      NIX_CFLAGS_COMPILE = "-std=gnu17";
    };
  });
  openbabel = prev.openbabel.overrideAttrs (old: lib.optionalAttrs (!lib.elem "test_align_4" old.disabledTests) {
    # https://github.com/NixOS/nixpkgs/pull/482731
    disabledTests = old.disabledTests ++ [
      # These tests fail with GCC 15
      "test_align_4"
      "test_align_5"
    ];
  });
  _86Box = prev._86Box.overrideAttrs (old: lib.optionalAttrs (old.version == "5.3") {
    patches = (old.patches or []) ++ [
      (final.fetchpatch {
        url = "https://github.com/starfrost013/86Box/commit/0092ce15de3efac108b961882f870a8c05e8c38f.patch";
        hash = "sha256-DqjOtnyk6Zv9XHCLeuxD1wcLfvjGwGFvUWS0alXcchs=";
      })
    ];
  });
}
