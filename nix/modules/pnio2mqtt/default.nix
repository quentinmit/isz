{ config, pkgs, lib, py-profinet, ... }: let
  cfg = config.isz.pnio2mqtt;
  configFormat = pkgs.formats.yaml {};
  configYaml = configFormat.generate "pnio2mqtt.yaml" cfg.settings;
  pkg = (pkgs.unstable.extend py-profinet.overlays.default).py-profinet;
in {
  options = with lib; {
    isz.pnio2mqtt = {
      enable = mkEnableOption "ProfinetIO to MQTT";
      settings = lib.mkOption {
        inherit (configFormat) type;
      };
    };
  };
  config = lib.mkIf cfg.enable {
    isz.pnio2mqtt.settings.gsdml = lib.mkDefault ./GSDML-V2.35-Phoenix_Contact-CAPAROC_PM_PN-20230203.xml;

    users.extraUsers.pnio2mqtt = {
      isSystemUser = true;
      group = "pnio2mqtt";
      # scapy requires $HOME to be writable
      createHome = true;
      home = "/var/lib/pnio2mqtt";
    };
    users.extraGroups.pnio2mqtt = {};
    systemd.services.pnio2mqtt = {
      description = "ProfinetIO to MQTT";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" "mosquitto.service" "influxdb2.service" ];
      after = [ "network-online.target" "mosquitto.service" "influxdb2.service" ];
      serviceConfig = {
        User = "pnio2mqtt";
        Group = "pnio2mqtt";
        Restart = "always";
        RestartSec = "5s";
        AmbientCapabilities = [ "CAP_NET_RAW" ];
        ExecStart = "${pkg}/bin/pnio2mqtt ${configYaml}";
      };
    };
  };
}
