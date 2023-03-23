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
    systemd.services.zwave-js-ui = {
      description = "Z-Wave JS UI";
      path = [ cfg.package ];
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      environment = {
        STORE_DIR = "\${STATE_DIRECTORY}/store";
        BACKUPS_DIR = "\${STATE_DIRECTORY}/store/backups";
        ZWAVE_JS_EXTERNAL_CONFIG = "\${STATE_DIRECTORY}/store/.config-db";
      };
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/zwave-js-ui";
        StateDirectory = "zwave-js-ui";
        WorkingDirectory = "\${STATE_DIRECTORY}";
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
