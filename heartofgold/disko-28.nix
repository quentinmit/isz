{ lib, config, ... }:
let
  inherit (config.disko.zpool28) name;
in {
  options.disko.zpool28 = {
    name = lib.mkOption {
      type = lib.types.str;
      default = "zpool28";
    };
    root = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  # FIXME: Exclude USB-connected drive that doesn't support SMART to prevent hangs.
  config.isz.telegraf.smart.excludes = ["/dev/sdn"];

  config.disko.devices = let
    zfsDisks = [
      "/dev/disk/by-id/ata-ST28000NM000C-3WM103_ZXA0KVF0" # wwn-0x5000c500e89392ad
      "/dev/disk/by-id/ata-ST28000NM000C-3WM103_ZXA1A1VQ" # wwn-0x5000c500e9c83cf2
      "/dev/disk/by-id/ata-ST28000NM000C-3WM103_ZXA1KX6T" # wwn-0x5000c500ea018dc4
      "/dev/disk/by-id/ata-ST28000NM000C-3WM103_ZXA2BJ7D" # wwn-0x5000c500eae48c8c
      "/dev/disk/by-id/ata-ST28000NM000C-3WM103_ZXA2D9YJ" # wwn-0x5000c500eaf21890
      "/dev/disk/by-id/ata-ST28000NM000C-3WM103_ZXA2DTBM" # wwn-0x5000c500eaeeb1ae
      "/dev/disk/by-id/ata-ST28000NM000C-3WM103_ZXA2H8JW" # wwn-0x5000c500eb00f1c7
      "/dev/disk/by-id/ata-ST28000NM000C-3WM103_ZXA2R8SL" # wwn-0x5000c500eb1ba5b4
      "/dev/disk/by-id/ata-ST28000NM000C-3WM103_ZXA2ZM28" # wwn-0x5000c500eb466fe6
      "/dev/disk/by-id/ata-ST28000NM000C-3WM103_ZXA2ZW68" # wwn-0x5000c500eb42d0c6
    ];
    deviceToDiskoName = device: lib.last (lib.splitString "_" device);
  in {
    disk = {
    } // (lib.genAttrs' zfsDisks (device: lib.nameValuePair (deviceToDiskoName device) {
      type = "disk";
      inherit device;
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "8G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
            };
          };
          zfs = {
            size = "100%";
            content = {
              type = "zfs";
              pool = name;
            };
          };
        };
      };
    }));
    zpool.${name} = {
      type = "zpool";
      mode.topology = {
        type = "topology";
        vdev = [{
          mode = "raidz2";
          members = map deviceToDiskoName zfsDisks;
        }];
        # FIXME: cache = [ "nvme0n1" ];
      };
      options = {
        ashift = "12";
        autotrim = "on";
      };
      rootFsOptions = {
        xattr = "sa";
        compression = "lz4";
        acltype = "posixacl";
        dnodesize = "auto";
        relatime = "on";
        canmount = "off";
        mountpoint = "/";
        encryption = "on";
        keyformat = "passphrase";
      };
      mountpoint = "/";
      datasets = if config.disko.zpool28.root then {
        backup = {
          type = "zfs_fs";
          mountpoint = "/srv/backup";
          options = {
            keyformat = "passphrase";
          };
        };
        heartofgold = {
          type = "zfs_fs";
          # heartofgold needs to be mentioned in config.fileSystems for the clevis module to unlock it; use noauto so it doesn't actually mount.
          mountpoint = "/unused";
          mountOptions = [ "noauto" ];
          options = {
            mountpoint = "/";
            canmount = "noauto";
            keyformat = "passphrase";
          };
        };
        "heartofgold/root" = {
          type = "zfs_fs";
          mountpoint = "/";
          options = {
            "com.sun:auto-snapshot" = "true";
          };
        };
        "heartofgold/nix" = {
          type = "zfs_fs";
          # /nix needs a mountpoint so that it will be mounted by the initrd
          mountpoint = "/nix";
          options = {
            atime = "off";
            "com.sun:auto-snapshot" = "false";
          };
        };
        "heartofgold/var" = {
          type = "zfs_fs";
          mountpoint = "/var";
          options."com.sun:auto-snapshot" = "true";
        };
        "heartofgold/var/backup".type = "zfs_fs";
        "heartofgold/var/backup/postgresql".type = "zfs_fs";
        "heartofgold/var/cache".type = "zfs_fs";
        "heartofgold/var/lib" = {
          type = "zfs_fs";
          mountpoint = "/var/lib";
        };
        "heartofgold/var/lib/jellyfin" = {
          type = "zfs_fs";
        };
        "heartofgold/var/lib/postgresql" = {
          type = "zfs_fs";
          options.atime = "off";
          options."com.sun:auto-snapshot" = "false";
        };
        "heartofgold/var/lib/bitmagnet" = {
          type = "zfs_fs";
          options.atime = "off";
          options.secondarycache = "metadata";
          options."com.sun:auto-snapshot" = "false";
        };
        "heartofgold/var/lib/nixos-containers".type = "zfs_fs";
        "heartofgold/var/lib/nixos-containers/rtorrent".type = "zfs_fs";
        "heartofgold/var/log" = {
          type = "zfs_fs";
          mountpoint = "/var/log";
        };
        "heartofgold/home" = {
          type = "zfs_fs";
          options = {
            "com.sun:auto-snapshot" = "true";
            normalization = "formD";
          };
        };
        "heartofgold/home/quentin" = {
          type = "zfs_fs";
        };
        "heartofgold/media" = {
          type = "zfs_fs";
          options = {
            recordsize = "1M";
            mountpoint = "/srv/media";
            secondarycache = "metadata";
            "com.sun:auto-snapshot" = "true";
            normalization = "formD";
          };
        };
        "heartofgold/media/media1e" = {
          type = "zfs_fs";
        };
      } else {
        placeholder = {
          type = "zfs_fs";
        };
      };
    };
  };
}
