{ lib, ... }:
{
  services.zfs = {
    autoScrub.enable = true;
  };
  disko.devices = {
    disk.nvme0n1 = {
      type = "disk";
      device = "/dev/nvme0n1";
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
              mountpoint = "/boot";
              mountOptions = [
                "defaults"
              ];
            };
          };
          swap = {
            priority = 2;
            size = "64G";
            content.type = "swap";
          };
          zfs = {
            priority = 4;
            size = "100%";
            content.type = "zfs";
            content.pool = "zpool";
          };
        };
      };
    };
    zpool.zpool = {
      type = "zpool";
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
        var = {
          type = "zfs_fs";
          mountpoint = "/var";
          options."com.sun:auto-snapshot" = "true";
        };
        "var/backup".type = "zfs_fs";
        "var/backup/postgresql".type = "zfs_fs";
        "var/cache".type = "zfs_fs";
        "var/lib" = {
          type = "zfs_fs";
          mountpoint = "/var/lib";
        };
        "var/lib/grafana".type = "zfs_fs";
        "var/lib/hass".type = "zfs_fs";
        "var/lib/homebox".type = "zfs_fs";
        "var/lib/influxdb2".type = "zfs_fs";
        "var/lib/inventree".type = "zfs_fs";
        "var/lib/libvirt".type = "zfs_fs";
        "var/lib/loki".type = "zfs_fs";
        "var/lib/mosquitto".type = "zfs_fs";
        "var/lib/paperless".type = "zfs_fs";
        "var/lib/postfix".type = "zfs_fs";
        "var/lib/postgresql" = {
          type = "zfs_fs";
          options = {
            atime = "off";
            recordsize = "16k";
          };
        };
        "var/lib/sdrtrunk".type = "zfs_fs";
        "var/lib/private".type = "zfs_fs";
        "var/lib/private/zwave-js-ui".type = "zfs_fs";
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
        "home/root" = {
          type = "zfs_fs";
          mountpoint = "/root";
        };
      };
    };
  };
}
