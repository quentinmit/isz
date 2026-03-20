{ config, lib, pkgs, ... }:
let
  cfg = config.services.piscsi;
in {
  options.services.piscsi = with lib; {
    enable = mkEnableOption "PiSCSI";
    package = mkOption {
      default = pkgs.piscsi;
      type = types.package;
    };
    imagesDirectory = mkOption {
      type = types.path;
      default = "/var/lib/piscsi/images";
    };
  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package
    ];
    boot.kernelParams = ["iomem=relaxed"];
    systemd.services.piscsi = {
      description = "PiSCSI service";
      path = [ cfg.package ];
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        ExecStart = "${lib.getExe' cfg.package "piscsi"} -r 7 -F ${cfg.imagesDirectory}";
        ExecStop = "${lib.getExe' cfg.package "scsictl"} -X";
        SyslogIdentifier = "PISCSI";
        StateDirectory = "piscsi/images";
      };
    };
    systemd.services.piscsi-web = {
      description = "PiSCSI-Web service";
      after = [
        "network-online.target"
        "piscsi.service"
      ];
      requires = [
        "network-online.target"
        "piscsi.service"
      ];
      wantedBy = [ "multi-user.target" ];
      environment.PISCSI_CONFIG_DIR = "/var/lib/piscsi/config";
      environment.PISCSI_SHARED_FILES = "/var/lib/piscsi/shared_files";
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        ExecStart = lib.getExe cfg.package.web;
        SyslogIdentifier = "PISCSIWEB";
        StateDirectory = "piscsi/config";
      };
    };
  };
}
