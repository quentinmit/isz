{ lib, config, pkgs, ... }:
{
  config = {
    services.telegraf.extraConfig = lib.mkIf config.isz.telegraf.zfs {
      inputs.execd = [{
        alias = "zfs_dataset";
        interval = config.isz.telegraf.interval.zpool;
        command = ["${pkgs.iszTelegraf.zfs_dataset}/bin/zfs_dataset_metrics.py"];
        signal = "STDIN";
        restart_delay = "10s";
        data_format = "influx";
      }];
    };
  };
}
