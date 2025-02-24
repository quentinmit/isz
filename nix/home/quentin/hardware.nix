{ config, lib, pkgs, ... }:
{
  options.isz.quentin.hardware.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.isz.quentin.enable;
  };

  config = lib.mkIf config.isz.quentin.hardware.enable {
    home.packages = with pkgs; [
      sigrok-cli
      pulseview
      gtkwave
      cutecom
      lxi-tools-gui
    ];
  };
}
