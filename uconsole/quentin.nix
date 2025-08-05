{ config, pkgs, lib, ... }:
{
  sops.secrets."chromium_gaia_config.json" = {
    key = "gaia_config";
    sopsFile = ../nix/home/chromium/secrets.yaml;
    mode = "0444";
  };
  home-manager.users.quentin = lib.mkMerge [
    {
      home.stateVersion = "24.11";

      isz.base = true;
      isz.graphical = true;
      #isz.quentin.enable = true;
      isz.plasma.enable = true;
      isz.quentin = {
        utilities.enable = true;
        hardware.enable = true;
        radio.enable = true;
      };

      programs.chromium = {
        enable = true;
        dictionaries = [
          pkgs.hunspellDictsChromium.en_US
        ];
        gaiaConfigFile = config.sops.secrets."chromium_gaia_config.json".path;
      };

      home.packages = with pkgs; [
        #retroarchFull
        (retroarch.withCores (
          cores:
            lib.filter
              (c:
                (c ? libretroCore)
                && (lib.meta.availableOn stdenv.hostPlatform c)
                && (c.pname != "libretro-parallel-n64")
                && (c.pname != "libretro-ppsspp")
              )
              (lib.attrValues cores)
        ))
      ];
    }
  ];
}
