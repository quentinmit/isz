{ lib, config, pkgs, ... }:
let
  cfg = config.isz.telegraf;
in {
  options = with lib; {
    isz.telegraf.zfs = mkEnableOption "ZFS";
  };
  config = lib.mkMerge [
    {
      #_module.check = false;
      services.telegraf.extraConfig = lib.mkIf config.isz.telegraf.zfs {
        inputs.zfs = [{
          poolMetrics = true;
        }];
      };
    }
  ];
}
