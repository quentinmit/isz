{ config, lib, pkgs, ... }:
let
  cfg = config.services.greptimedb;
  configFormat = pkgs.formats.toml {};
  configFile = configFormat.generate "greptime-config.toml" cfg.config;
in {
  options.services.greptimedb = with lib; {
    enable = mkEnableOption "GreptimeDB";
    package = mkOption {
      type = types.package;
      default = pkgs.greptimedb;
    };
    user = mkOption {
      type = types.str;
      default = "greptimedb";
    };
    config = mkOption {
      type = configFormat.type;
      default = {};
    };
  };
  config = lib.mkIf cfg.enable {
    services.greptimedb.config = {
      enable_telemetry = lib.mkDefault false;
      storage.type = lib.mkDefault "File";
      storage.data_home = lib.mkDefault "/var/lib/greptimedb/data";
      logging.dir = lib.mkDefault "/var/log/greptimedb"; # TODO: Disable file logging when supported upstream
    };
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.user;
    };
    users.groups.${cfg.user} = {};
    systemd.services.greptimedb = {
      description = "GreptimeDB";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Restart = "always";
        RestartSec = "5s";
        User = cfg.user;
        Group = cfg.user;
        StateDirectory = lib.mkIf (cfg.config.storage.type == "File" && cfg.config.storage.data_home == "/var/lib/greptimedb/data") "greptimedb";
        LogsDirectory = lib.mkIf (cfg.config.storage.type == "File" && cfg.config.logging.dir == "/var/log/greptimedb") "greptimedb";
        ExecStart = "${lib.getExe cfg.package} standalone start --config-file ${configFile}";
      };
    };
  };
}
