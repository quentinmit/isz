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
      host = mkOption {
        type = types.str;
        default = "local";
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
  config = let cfg = config.services.speedtest-influxdb; in with builtins; {
    systemd.services.speedtest-influxdb = lib.mkIf cfg.enable {
      description = "Speedtest to InfluxDB";
      path = [ pkgs.speedtest-influxdb ];
      after = [ "network-online.target" ];
      script = ''
        exec speedtext-influxdb \
          -influxHost=${toJSON cfg.influxdb.url} \
          -influxDB=${toJSON cfg.influxdb.db} \
          -influxUser=${toJSON cfg.influxdb.username} \
          -influxPwd="$(cat ${toJSON cfg.influxdb.passwordPath})" \
          -interval=${toJSON cfg.interval} \
          -retryInterval=${toJSON cfg.retryInterval} \
          -host=${toJSON cfg.host} \
          -server=${toJSON cfg.speedtestServer} \
          -includeHumanOutput=${if cfg.includeReadableOutput then "true" else "false"} \
          -retryZeroValue=${if cfg.retryZeroValue then "true" else "false"} \
          -distanceUnit=${toJSON cfg.distanceUnit} \
          -showExternalIp=${if cfg.showExternalIp then "true" else "false"} \
          -keepProcessRunning=true \
          -saveToInfluxDb=true
      '';
    };
  };
}
