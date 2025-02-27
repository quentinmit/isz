{ config, pkgs, lib, ... }:
{
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
