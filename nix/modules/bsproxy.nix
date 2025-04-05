{ lib, pkgs, config, options, ... }:
let
  cfg = config.services.bsproxy;
in {
  options = with lib; {
    services.bsproxy = {
      enable = mkEnableOption "Run a bsproxy to proxy Bambu printer advertisements";
      inputInterfaces = mkOption {
        type = types.listOf types.str;
      };
      outputInterfaces = mkOption {
        type = types.listOf types.str;
      };
    };
  };
  config = lib.mkIf cfg.enable {
    systemd.services.bsproxy = {
      description = "Bambu discovery proxy";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Restart = "always";
        RestartSec = "5s";
        ExecStart = ''${lib.getExe pkgs.bsproxy}${lib.concatMapStrings (x: " -i "+x) cfg.inputInterfaces}${lib.concatMapStrings (x: " -o "+x) cfg.outputInterfaces}'';
      };
    };
  };
}
