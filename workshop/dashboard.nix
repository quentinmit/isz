{ lib, pkgs, config, options, ... }:
{
  options = with lib; {
    services.dashboard = {
      enable = mkEnableOption "dashboard";
      influxdb = {
        tokenPath = mkOption {
          type = types.path;
          description = ''Path to file containing InfluxDB token'';
        };
        # url = mkOption {
        #   type = types.str;
        #   default = "http://127.0.0.1:8086";
        # };
        # org = mkOption {
        #   type = types.str;
        # };
        # bucket = mkOption {
        #   type = types.str;
        #   default = "rtlamr";
        # };
      };
      user = mkOption {
        type = types.str;
        default = "dashboard";
      };
    };
  };
  config = let cfg = config.services.dashboard; in lib.mkIf cfg.enable {
    users.extraUsers.${cfg.user} = {
      isSystemUser = true;
      group = cfg.user;
    };
    users.extraGroups.${cfg.user} = {};
    systemd.services.dashboard = {
      description = "ISZ Dashboard";
      after = [
        "network.target"
        "mosquitto.service"
        "influxdb2.service"
      ];
      wants = [
        "influxdb2.service"
      ];
      wantedBy = [ "multi-user.target" ];
      script = with lib.strings; ''
        export INFLUX_TOKEN="$(cat ${escapeShellArg cfg.influxdb.tokenPath})"
        set -e
        exec ${pkgs.dashboard}/bin/dashboard-graph
      '';
      unitConfig = {
        StartLimitIntervalSec = "0";
      };
      serviceConfig = {
        Restart = "always";
        RestartSec = "5s";
        User = cfg.user;
        Group = cfg.user;
      };
    };
  };
}
