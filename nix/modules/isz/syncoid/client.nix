{ config, lib, ... }:
let
  cfg = config.isz.syncoid;
in {
  options = {
    isz.sanoid.enable = lib.mkEnableOption "Sanoid snapshots";
    isz.syncoid = {
      enable = lib.mkEnableOption "Syncoid backups";
      targets = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
          options = {
            hostName = lib.mkOption {
              type = lib.types.str;
              default = "${name}.isz.wtf";
            };
            sources = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = builtins.attrNames config.disko.devices.zpool;
            };
            pool = lib.mkOption {
              type = lib.types.str;
              default = "zpool";
            };
            sendHolds = lib.mkOption {
              type = lib.types.bool;
              default = false;
            };
            excludeDatasets = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = lib.mapAttrsToList (name: _: "${name}/nix") config.disko.devices.zpool;
            };
          };
        }));
        default = {};
      };
    };
  };
  config = lib.mkMerge [
    (lib.mkIf config.isz.sanoid.enable {
      services.zfs.autoSnapshot.enable = false;
      services.sanoid = {
        enable = true;
        # https://github.com/jimsalterjrs/sanoid/issues/957
        extraArgs = [ "--cache-ttl=600" ];
        interval = lib.mkDefault "*:0/15";
        templates.default = {
          frequently = lib.mkDefault 4;
          hourly = lib.mkDefault 24;
          # Temporarily double number of snapshots to work around https://github.com/jimsalterjrs/sanoid/issues/957
          daily = lib.mkDefault (2*7);
          monthly = lib.mkDefault (2*12);
          yearly = lib.mkDefault 0;
        };
        datasets = lib.mkDefault (lib.mapAttrs (_: _: {
          use_template = ["default"];
          recursive = "zfs";
        }) config.disko.devices.zpool);
      };
    })
    (lib.mkIf cfg.enable {
      isz.syncoid.targets.heartofgold = {
        hostName = "heartofgold.mgmt.isz.wtf";
        pool = "zpool";
        # Don't propagate holds if there are more than one target, because nothing will ever release those holds on other targets.
        sendHolds = (builtins.attrNames cfg.targets) == ["heartofgold"];
      };
    })
    {
      isz.sanoid.enable = lib.mkIf (cfg.targets != {}) true;
      sops.secrets = lib.mapAttrs' (name: _: lib.nameValuePair "syncoid/ssh_keys/${name}" {
        owner = config.services.syncoid.user;
      }) cfg.targets;
      services.syncoid = lib.mkIf (cfg.targets != {}) {
        enable = true;
        interval = lib.mkDefault "0/3:10"; # Every 3 hours at :10 after the hour
        localSourceAllow = [
          "bookmark"
          "hold"
          "release"
          "send"
          "snapshot"
          "destroy"
          "mount"
        ];
        commands = lib.concatMapAttrs (targetName: target:
          lib.genAttrs' target.sources (source: lib.nameValuePair "${source}-${targetName}" {
            extraArgs = [
              "--debug"
              "--no-sync-snap"
              "--use-hold"
              #"--create-bookmark"
              #"--force-delete"
              "--identifier" targetName
            ];
            sendOptions = "Rw${lib.optionalString target.sendHolds "h"}${lib.concatMapStrings (name: " X ${name}") target.excludeDatasets}";
            recvOptions = "v u o canmount=off o secondarycache=none o mountpoint=/srv/backup/${config.networking.hostName}/${source} o com.sun:auto-snapshot=false o readonly=on";
            inherit source;
            target = "syncoid-${config.networking.hostName}@${target.hostName}:${target.pool}/backup/${config.networking.hostName}/${source}";
            sshKey = config.sops.secrets."syncoid/ssh_keys/${targetName}".path;
          })) cfg.targets;
      };
    }
  ];
}
