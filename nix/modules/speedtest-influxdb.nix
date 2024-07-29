{ lib, pkgs, config, options, ... }:
{
  options = with lib; {
    services.speedtest-influxdb = {
      enable = mkEnableOption "speedtest-influxdb";
      influxdb = {
        passwordPath = mkOption {
          type = types.path;
          description = ''Path to file containing InfluxDB password.'';
        };
        username = mkOption {
          type = types.str;
          description = "InfluxDB username.";
        };
        url = mkOption {
          type = types.str;
          default = "http://127.0.0.1:8086";
        };
        db = mkOption {
          type = types.str;
        };
      };
      interval = mkOption {
        type = types.int;
        default = 3600;
      };
      retryInterval = mkOption {
        type = types.int;
        default = 300;
      };
      hosts = mkOption {
        type = types.listOf types.str;
        default = ["local"];
      };
      speedtestServer = mkOption {
        type = types.str;
        default = "";
      };
      includeReadableOutput = mkEnableOption "include readable output";
      retryZeroValue = mkEnableOption "retry zero values";
      distanceUnit = mkOption {
        type = types.enum [ "km" "nm" "mi" ];
        default = "km";
        apply = v: { km="K"; nm="N"; mi="M"; }.${v};
      };
      showExternalIp = mkEnableOption "show external IP";
    };
  };
  config = let
    cfg = config.services.speedtest-influxdb;
    inherit (lib.strings) escapeShellArg;
  in lib.mkIf cfg.enable {
    systemd.services = (lib.genAttrs (map (n: "speedtest-influxdb@${n}") cfg.hosts) (_: {
      wantedBy = [ "multi-user.target" ];
    })) // {
      "speedtest-influxdb@" = {
        description = "Speedtest to InfluxDB";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        environment.HOST = "%I";
        script = ''
          exec ${pkgs.speedtest-influxdb}/bin/speedtest-influxdb \
            -influxHost=${escapeShellArg cfg.influxdb.url} \
            -influxDB=${escapeShellArg cfg.influxdb.db} \
            -influxUser=${escapeShellArg cfg.influxdb.username} \
            -influxPwd="$(cat ${escapeShellArg cfg.influxdb.passwordPath})" \
            -interval=${escapeShellArg cfg.interval} \
            -retryInterval=${escapeShellArg cfg.retryInterval} \
            -host=$HOST \
            -server=${escapeShellArg cfg.speedtestServer} \
            -includeHumanOutput=${if cfg.includeReadableOutput then "true" else "false"} \
            -retryZeroValue=${if cfg.retryZeroValue then "true" else "false"} \
            -distanceUnit=${escapeShellArg cfg.distanceUnit} \
            -showExternalIp=${if cfg.showExternalIp then "true" else "false"} \
            -keepProcessRunning=true \
            -saveToInfluxDb=true
        '';
        unitConfig = {
          StartLimitIntervalSec = "0";
        };
        serviceConfig = {
          User = "speedtest-influxdb";
          Group = "speedtest-influxdb";
          Restart = "always";
          RestartSec = "5s";
        };
      };
    };
    users.extraUsers.speedtest-influxdb = {
      isSystemUser = true;
      group = "speedtest-influxdb";
    };
    users.extraGroups.speedtest-influxdb = {};
  };
}
