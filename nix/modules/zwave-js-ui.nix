{ lib, pkgs, config, options, ... }:
{
  options = with lib; {
    services.zwave-js-ui = {
      enable = mkEnableOption "zwave-js-ui";
      package = mkOption {
        default = pkgs.zwave-js-ui-bin;
        type = types.package;
      };
    };
  };
  config = let cfg = config.services.zwave-js-ui; in with lib.strings; lib.mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package
    ];
    systemd.services.zwave-js-ui = let stateDir = "zwave-js-ui"; in {
      description = "Z-Wave JS UI";
      path = [ cfg.package ];
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      environment = {
        HOME = "%t/${stateDir}";
        STORE_DIR = "%S/${stateDir}";
        BACKUPS_DIR = "%S/${stateDir}/backups";
        ZWAVE_JS_EXTERNAL_CONFIG = "%S/${stateDir}/.config-db";
      };
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/zwave-js-ui";
        StateDirectory = stateDir;
        WorkingDirectory = "%S/${stateDir}";
        RuntimeDirectory = stateDir;
        User = "zwave-js-ui";
        Group = "zwave-js-ui";
        Restart = "on-failure";
      };
    };
    users.extraUsers.zwave-js-ui = {
      isSystemUser = true;
      group = "zwave-js-ui";
    };
    users.extraGroups.zwave-js-ui = {};
  };
}
