{ lib, pkgs, config, options, ...}@args:
let
  cfg = config.isz.telegraf.mikrotik.api;
  interval = config.isz.telegraf.interval.mikrotik;
in {
  options = with lib; {
    isz.telegraf.mikrotik.api = let trg = with types; submodule {
      options = {
        ip = mkOption { type = str; };
        user = mkOption { type = str; };
        password = mkOption { type = str; };
        plaintext = mkOption { type = bool; default = false; };
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
      alias = "mikrotik_api_${host.ip}";
      command = [
        "${pkgs.iszTelegraf.mikrotik}/bin/mikrotik_metrics.py"
        "--server"
        host.ip
        "--user"
        host.user
        "--password"
        host.password
      ] ++ (if host.plaintext then ["--plaintext-login"] else []);
      signal = "STDIN";
      inherit interval;
      restart_delay = "10s";
      data_format = "influx";
      name_prefix = "mikrotik-";
    }) cfg.targets;
  };
}
