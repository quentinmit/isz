{ lib, pkgs, config, options, ... }:
{
  options = with lib; {
    services.rtl-tcp = {
      enable = mkOption{
        default = false;
        type = with types; bool;
        description = ''
          Start an rtl-tcp server on USB hotplug.
        '';
      };
      usbVid = mkOption{
        default = 0x0bda;
        type = with types; nullOr (u16);
        description = ''USB VID.'';
      };
      usbPid = mkOption{
        default = 0x2838;
        type = with types; nullOr (u16);
        description = ''USB PID.'';
      };
    };
    services.rtlamr-collect = {
      enable = mkEnableOption "rtlamr-collect";
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
  config = {
    services.rtlamr-collect.strictIdm = lib.mkDerivedConfig options.services.rtlamr-collect.msgtype (mt:
      let mtl = lib.strings.splitString "," mt;
      in
        (lib.lists.any (t: t == "netidm") mtl)
        && (lib.lists.any (t: t == "idm") mtl)
    );
    hardware.rtl-sdr.enable = true;
    environment.systemPackages = with pkgs; [
      rtl-sdr
      rtlamr
      rtlamr-collect
    ];
    systemd.services.rtl-tcp = lib.mkIf config.services.rtl-tcp.enable {
      description = "RTL-SDR TCP server";
      path = [ pkgs.rtl-sdr ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = ''${pkgs.rtl-sdr}/bin/rtl_tcp -a 0.0.0.0'';
      };
    };
    # TODO: Put rule in a package and use services.udev.packages
    services.udev.extraRules = lib.mkIf config.services.rtl-tcp.enable ''
      SUBSYSTEM=="usb", DRIVER=="usb", ATTR{idProduct}=="${config.services.rtl-tcp.usbVid}", ATTR{idVendor}=="${config.services.rtl-tcp.usbPid}", TAG+="systemd", ENV{SYSTEMD_WANTS}+="rtl-tcp"
    '';
    systemd.services.rtlamr-collect = let cfg = config.services.rtlamr-collect; in lib.mkIf config.services.rtlamr-collect.enable {
      description = "Collect rtlamr data";
      path = [ pkgs.rtlamr pkgs.rtlamr-collect ];
      after = [ "network.target" "rtl-tcp.service" ];
      requires = [ "rtl-tcp.service" ];
      wantedBy = [ "rtl-tcp.service" ];
      script = with builtins; ''
        export COLLECT_INFLUXDB_HOSTNAME=${toJSON cfg.influxdb.url}
        export COLLECT_INFLUXDB_ORG=${toJSON cfg.influxdb.org}
        export COLLECT_INFLUXDB_BUCKET=${toJSON cfg.influxdb.bucket}
        export COLLECT_INFLUXDB_MEASUREMENT=${toJSON cfg.influxdb.measurement}
        export COLLECT_STRICTIDM=${if cfg.strictIdm then "1" else "0"}
        export COLLECT_LOGLEVEL=${toJSON cfg.logLevel}
        export RTLAMR_FORMAT=json
        export RTLAMR_MSGTYPE=${toJSON cfg.msgtype}
        export RTLAMR_SERVER=${toJSON cfg.rtlTcpServer}
        export COLLECT_INFLUXDB_TOKEN="$(cat ${toJSON cfg.influxdb.tokenPath})"
        set -e
        rtlamr | rtlamr-collect
      '';
    };
  };
}
