{ lib, config, pkgs, ... }:
{
  options = with lib; {
    isz.telegraf.drm = mkEnableOption "drm";
  };
  config = {
    services.telegraf.extraConfig = lib.mkIf config.isz.telegraf.drm {
      inputs.execd = [{
        alias = "drm";
        restart_delay = "10s";
        data_format = "influx";
        command = [pkgs.iszTelegraf.drm];
        signal = "STDIN";
      }];
    };
  };
}
