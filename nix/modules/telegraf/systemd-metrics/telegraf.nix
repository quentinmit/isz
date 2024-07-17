{ lib, config, pkgs, ... }:
{
  config = {
    services.telegraf.extraConfig = lib.mkIf (config.isz.telegraf.enable && pkgs.stdenv.isLinux) {
      inputs.execd = [{
        interval = config.isz.telegraf.interval.cgroup;
        alias = "systemd_user";
        restart_delay = "10s";
        data_format = "influx";
        command = [ "${pkgs.systemd-metrics}/bin/systemd-metrics" "--get-all" ];
        signal = "STDIN";
      }];
    };
  };
}
