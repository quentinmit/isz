{ lib, config, pkgs, ... }:
let
  cfg = config.isz.telegraf;
in {
  options = with lib; {
    isz.telegraf.zfs = mkEnableOption "ZFS";
  };
  config = lib.mkMerge [
    {
      isz.telegraf.interval.zpool = lib.mkOptionDefault "60s";
      #_module.check = false;
      services.telegraf.extraConfig = lib.mkIf config.isz.telegraf.zfs {
        inputs.zfs = [{
          poolMetrics = true;
        }];
        inputs.execd = [{
          alias = "zpool_influxdb";
          interval = config.isz.telegraf.interval.zpool;
          restart_delay = "10s";
          data_format = "influx";
          command = [
            "${pkgs.zfs}/libexec/zfs/zpool_influxdb"
            "--execd"
            "--sum-histogram-buckets"
          ];
          signal = "STDIN";
        }];
      };
    }
  ];
}
