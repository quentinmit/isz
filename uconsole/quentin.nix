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
    }
  ];
}
