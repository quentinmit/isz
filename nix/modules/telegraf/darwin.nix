{ lib, pkgs, config, options, ... }:
{
  options = with lib; {
    launchd.daemons = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          serviceConfig = mkOption {
            type = types.submodule {
              options = {
                SessionCreate = mkOption {
                  type = types.nullOr types.bool;
                  default = null;
                  description = "Create a new audit context";
                };
              };
            };
          };
        };
      });
    };
  };
  config = let
    cfg = config.isz.telegraf;
  in lib.mkMerge [
    (lib.mkIf cfg.enable {
      #services.telegraf.environmentFiles = [
      #  config.sops.secrets.telegraf.path
      #];
      users.users.telegraf = {
        description = "Telegraf";
        isHidden = true;
      };
      users.groups.telegraf = {
        members = ["telegraf"];
      };
      launchd.daemons.telegraf.serviceConfig.UserName = "telegraf";
      launchd.daemons.telegraf.serviceConfig.GroupName = "telegraf";
      launchd.daemons.telegraf.serviceConfig.SessionCreate = true;
      launchd.daemons.telegraf.serviceConfig.ExitTimeOut = 600;
    })
  ];
}
