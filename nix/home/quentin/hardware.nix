{ config, lib, pkgs, ... }:
let
  available = pkg: lib.optional pkg.meta.available pkg;
in {
  options.isz.quentin.hardware.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.isz.quentin.enable;
  };

  config = lib.mkIf config.isz.quentin.hardware.enable (lib.mkMerge [
    {
      home.packages = with pkgs; [
        sigrok-cli
      ];
    }
    (lib.mkIf config.isz.graphical {
      home.packages = with pkgs; [
        pulseview
        gtkwave
        cutecom
        lxi-tools-gui
    ] ++ (available qflipper);
    })
  ]);
}
