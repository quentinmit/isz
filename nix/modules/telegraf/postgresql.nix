{ lib, options, config, pkgs, ... }:
let
  cfg = config.isz.telegraf;
  isNixOS = options ? security.wrappers;
in {
  options = with lib; {
    isz.telegraf.postgresql = mkEnableOption "PostgreSQL support" // {
      default = config.services.postgresql.enable or false;
    };
  };
  config = lib.mkMerge [
    (lib.mkIf config.isz.telegraf.postgresql {
      services.telegraf.extraConfig.inputs.postgresql = [{
        address = "postgresql://";
      }];
    })
    (lib.optionalAttrs isNixOS (lib.mkIf (cfg.enable && cfg.postgresql) {
      services.postgresql = {
        ensureUsers = [{
          name = "telegraf";
          ensureDBOwnership = true;
        }];
        ensureDatabases = [ "telegraf" ];
      };
    }))
  ];
}
