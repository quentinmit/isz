{ lib, pkgs, config, options, ...}@args:
let
  cfg = config.isz.telegraf.mikrotik.swos;
  interval = config.isz.telegraf.interval.mikrotik;
in {
  options = with lib; {
    isz.telegraf.mikrotik.swos = let trg = with types; submodule {
      options = {
        ip = mkOption { type = str; };
        user = mkOption { type = str; };
        password = mkOption { type = str; };
      };
    }; in {
      targets = mkOption {
        default = [];
        type = with types; listOf trg;
      };
    };
  };
  config.services.telegraf.extraConfig = lib.mkIf (cfg.targets != []) {
    inputs.execd = map (host: {
      alias = "mikrotik_swos_${host.ip}";
      command = [
        "${pkgs.iszTelegraf.mikrotik}/bin/mikrotik_swos_metrics.py"
        "--server"
        host.ip
        "--user"
        host.user
        "--password"
        host.password
      ];
      signal = "STDIN";
      inherit interval;
      restart_delay = "10s";
      data_format = "influx";
      name_prefix = "mikrotik-";
    }) cfg.targets;
  };
}
