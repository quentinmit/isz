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
  config = lib.mkIf (config.isz.syncoid.sinks != {}) {
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
    # TODO: zfs allow -u syncoid-${name} compression,canmount,mountpoint,acltype,atime,recordsize,relatime,xattr,dnodesize,secondarycache,readonly,userprop,create,mount,receive,hold,release,rollback,destroy,change-key,release ${pool}/backup/${name}
  };
}
