{ lib, config, pkgs, ... }:
{
  options = with lib; {
    isz.telegraf.powerSupply = mkEnableOption "power_supply";
  };
  config = {
    services.telegraf.extraConfig = lib.mkIf config.isz.telegraf.powerSupply {
      inputs.execd = [{
        alias = "power_supply";
        restart_delay = "10s";
        data_format = "influx";
        command = [pkgs.iszTelegraf.power_supply];
        signal = "STDIN";
      }];
    };
  };
}
