{ lib, config, pkgs, ... }:
{
  options = with lib; {
    isz.telegraf.w1 = mkEnableOption "1-Wire support";
  };
  config = {
    services.telegraf.extraConfig = lib.mkIf config.isz.telegraf.w1 {
      inputs.execd = [{
        alias = "w1";
        command = ["${pkgs.iszTelegraf.w1}/bin/w1_metrics.py"];
        signal = "STDIN";
        restart_delay = "10s";
        data_format = "influx";
      }];
    };
  };
}
