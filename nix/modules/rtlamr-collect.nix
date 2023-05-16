{ lib, pkgs, config, options, ... }:
{
  imports = [
    ./udev.nix
  ];
  options = with lib; {
    services.rtl-tcp = {
      enable = mkOption{
        default = false;
        type = with types; bool;
        description = ''
          Start an rtl-tcp server on USB hotplug.
        '';
      };
      # TODO: https://github.com/NixOS/nix/pull/7695
      usbVid = mkOption{
        default = "0bda";
        type = with types; nullOr str; # (ints.u16);
        description = ''USB VID.'';
      };
      usbPid = mkOption{
        default = "2838";
        type = with types; nullOr str; # (ints.u16);
        description = ''USB PID.'';
      };
    };
    services.rtlamr-collect = {
      enable = mkEnableOption "rtlamr-collect";
      user = mkOption {
        type = types.str;
        default = "rtlamr-collect";
      };
      influxdb = {
        tokenPath = mkOption {
          type = types.path;
          description = ''Path to file containing InfluxDB token'';
        };
        url = mkOption {
          type = types.str;
          default = "http://127.0.0.1:8086";
        };
        org = mkOption {
          type = types.str;
        };
        bucket = mkOption {
          type = types.str;
          default = "rtlamr";
        };
        measurement = mkOption {
          type = types.str;
          default = "rtlamr";
        };
      };
      strictIdm = mkOption {
        type = types.bool;
        description = "Ignores IDM with type 8 and NetIDM with type 7.";
      };
      msgtype = mkOption {
        type = types.commas;
        default = "scm,scm+,idm";
        description = "List of meter types to decode.";
      };
      logLevel = mkOption {
        type = types.enum [ "panic" "fatal" "error" "warn" "info" "debug" "trace" ];
        default = "info";
        description = "Log level";
      };
      rtlTcpServer = mkOption {
        type = types.str;
        default = "127.0.0.1:1234";
        description = "RTL-TCP server";
      };
    };
  };
  config = lib.mkMerge [
    {
      services.rtlamr-collect.strictIdm = lib.mkDerivedConfig options.services.rtlamr-collect.msgtype (mt:
        let mtl = lib.strings.splitString "," mt;
        in
          (lib.lists.any (t: t == "netidm") mtl)
          && (lib.lists.any (t: t == "idm") mtl)
      );
    }
    (lib.mkIf config.services.rtl-tcp.enable {
      hardware.rtl-sdr.enable = true;
      environment.systemPackages = with pkgs; [
        rtl-sdr
      ];
      systemd.services.rtl-tcp = {
        description = "RTL-SDR TCP server";
        path = [ pkgs.rtl-sdr ];
        after = [ "network.target" ];
        serviceConfig = {
          ExecStart = ''${pkgs.rtl-sdr}/bin/rtl_tcp -a 0.0.0.0'';
        };
      };
      services.udev.rules = [{
        SUBSYSTEM = "usb";
        DRIVER = "usb";
        "ATTR{idVendor}" = config.services.rtl-tcp.usbVid;
        "ATTR{idProduct}" = config.services.rtl-tcp.usbPid;
        TAG = { op = "+="; value = "systemd"; };
        "ENV{SYSTEMD_WANTS}" = { op = "+="; value = "rtl-tcp"; };
      }];
    })
    (let
      cfg = config.services.rtlamr-collect;
    in lib.mkIf cfg.enable {
      environment.systemPackages = with pkgs; [
        rtlamr
        rtlamr-collect
      ];
      users.extraUsers.${cfg.user} = {
        isSystemUser = true;
        group = cfg.user;
      };
      users.extraGroups.${cfg.user} = {};
      systemd.services.rtlamr-collect = {
        description = "Collect rtlamr data";
        path = [ pkgs.rtlamr pkgs.rtlamr-collect ];
        wants = [ "influxdb2.service" ];
        after = [ "network.target" "rtl-tcp.service" "influxdb2.service" ];
        requires = [ "rtl-tcp.service" ];
        wantedBy = [ "rtl-tcp.service" ];
        script = with lib.strings; ''
          export COLLECT_INFLUXDB_HOSTNAME=${escapeShellArg cfg.influxdb.url}
          export COLLECT_INFLUXDB_ORG=${escapeShellArg cfg.influxdb.org}
          export COLLECT_INFLUXDB_BUCKET=${escapeShellArg cfg.influxdb.bucket}
          export COLLECT_INFLUXDB_MEASUREMENT=${escapeShellArg cfg.influxdb.measurement}
          export COLLECT_STRICTIDM=${if cfg.strictIdm then "1" else "0"}
          export COLLECT_LOGLEVEL=${escapeShellArg cfg.logLevel}
          export RTLAMR_FORMAT=json
          export RTLAMR_MSGTYPE=${escapeShellArg cfg.msgtype}
          export RTLAMR_SERVER=${escapeShellArg cfg.rtlTcpServer}
          export COLLECT_INFLUXDB_TOKEN="$(cat ${escapeShellArg cfg.influxdb.tokenPath})"
          set -e
          rtlamr | rtlamr-collect
        '';
        serviceConfig = {
          Restart = "always";
          RestartSec = "5s";
          StartLimitIntervalSec = "0";
          User = cfg.user;
          Group = cfg.user;
          StateDirectory = "rtlamr-collect";
          WorkingDirectory = "%S/rtlamr-collect";
        };
      };
    })
  ];
}
