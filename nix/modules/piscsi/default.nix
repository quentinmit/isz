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
  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package
    ];
    systemd.services.piscsi = let stateDir = "zwave-js-ui"; in {
      description = "PiSCSI service";
      path = [ cfg.package ];
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        ExecStart = "${lib.getExe' cfg.package "piscsi"} -r 7";
        ExecStop = "${lib.getExe' cfg.package "scsictl"} -X";
        SyslogIdentifier = "PISCSI";
      };
    };
  };
}
