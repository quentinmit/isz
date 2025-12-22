{ config, pkgs, lib, ... }:
{
  options = with lib; {
    isz.syncoid.sinks = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          keys = mkOption {
            type = types.listOf types.str;
          };
        };
      });
      default = {};
    };
  };
  config = {
    environment.systemPackages = with pkgs; [
      mbuffer
    ];
    users.groups.syncoid-targets = {};
    users.users = lib.mapAttrs' (name: config: lib.nameValuePair "syncoid-${name}" {
      isSystemUser = true;
      group = "syncoid-targets";
      shell = pkgs.bash;
      openssh.authorizedKeys.keys = config.keys;
    }) config.isz.syncoid.sinks;

    isz.syncoid.sinks = {
      workshop.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJp0JhnfZevlSxn5DSVOaybntyM1OkNLKOzZi50yL+yX"
      ];
      atlas.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICpQWTeqqoTiy1fk4zU0YiAKTAeqkgHHeY30ERcBvzqB"
      ];
    };
  };
}
