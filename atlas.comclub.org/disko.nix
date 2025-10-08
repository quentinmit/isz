{ lib, ... }:
{
  services.zfs = {
    autoScrub.enable = true;
    autoSnapshot.enable = true;
  };
  disko.devices = {
    disk = lib.genAttrs [
      "nvme0n1"
      "nvme1n1"
    ] (dev: {
      type = "disk";
      device = "/dev/${dev}";
      imageSize = "128G";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            priority = 1;
            size = "8G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
            } // lib.optionalAttrs (dev == "nvme0n1") {
              mountpoint = "/boot";
              mountOptions = [
                "defaults"
              ];
            };
          };
          swap = {
            priority = 2;
            size = "64G";
            content.type = "mdraid";
            content.name = "swap";
          };
          zfs = {
            priority = 4;
            size = "100%";
            content.type = "zfs";
            content.pool = "zpool";
          };
        };
      };
    });
    mdadm.swap = {
      type = "mdadm";
      level = 1;
      content.type = "swap";
      content.randomEncryption = true;
    };
    zpool.zpool = {
      type = "zpool";
      mode = "mirror";
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
      datasets = {
        root = {
          type = "zfs_fs";
          mountpoint = "/";
          options = {
            "com.sun:auto-snapshot" = "true";
          };
        };
        nix = {
          type = "zfs_fs";
          # /nix needs a mountpoint so that it will be mounted by the initrd
          mountpoint = "/nix";
          options = {
            atime = "off";
            "com.sun:auto-snapshot" = "false";
          };
        };
        tmp.type = "zfs_fs";
        var = {
          type = "zfs_fs";
          mountpoint = "/var";
          options."com.sun:auto-snapshot" = "true";
        };
        "var/backup".type = "zfs_fs";
        "var/backup/postgresql".type = "zfs_fs";
        "var/backup/timecapsule".type = "zfs_fs";
        "var/cache".type = "zfs_fs";
        "var/lib" = {
          type = "zfs_fs";
          mountpoint = "/var/lib";
        };
        "var/lib/hass".type = "zfs_fs";
        "var/lib/libvirt".type = "zfs_fs";
        "var/lib/mail" = {
          type = "zfs_fs";
          options.atime = "off";
        };
        "var/lib/netatalk".type = "zfs_fs";
        "var/lib/postfix".type = "zfs_fs";
        "var/lib/postgresql" = {
          type = "zfs_fs";
          options = {
            atime = "off";
            recordsize = "16k";
          };
        };
        "var/lib/private".type = "zfs_fs";
        "var/lib/private/zwave-js-ui".type = "zfs_fs";
        "var/lib/timecapsule".type = "zfs_fs";
        "var/log" = {
          type = "zfs_fs";
          mountpoint = "/var/log";
        };
        "var/spool".type = "zfs_fs";
        "var/spool/mail".type = "zfs_fs";
        "var/tmp".type = "zfs_fs";
        home = {
          type = "zfs_fs";
          options = {
            "com.sun:auto-snapshot" = "true";
            normalization = "formD";
          };
        };
        "home/root".type = "zfs_fs";
      };
    };
  };
}
