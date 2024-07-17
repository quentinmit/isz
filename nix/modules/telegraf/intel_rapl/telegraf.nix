{ lib, config, pkgs, isNixOS, ... }:
let
  cfg = config.isz.telegraf;
in {
  options = with lib; {
    isz.telegraf.intelRapl = mkEnableOption "intel_rapl";
  };
  config = lib.mkMerge [
    (lib.mkIf (isNixOS && cfg.enable && cfg.intelRapl) {
      security.wrappers.intel_rapl_telegraf = {
        source = pkgs.iszTelegraf.intel_rapl;
        owner = "root";
        group = "telegraf";
        permissions = "u+rx,g+x";
        setuid = true;
      };
      systemd.services.telegraf.reloadTriggers = [pkgs.iszTelegraf.intel_rapl];
    })
    {
      #_module.check = false;
      services.telegraf.extraConfig = lib.mkIf config.isz.telegraf.intelRapl {
        inputs.execd = [{
          alias = "intel_rapl";
          restart_delay = "10s";
          data_format = "influx";
          command = [(if isNixOS then "/run/wrappers/bin/intel_rapl_telegraf" else pkgs.iszTelegraf.intel_rapl)];
          signal = "STDIN";
        }];
      };
    }
  ];
}
