{ lib, ... }:
{
  services.zfs = {
    autoScrub.enable = true;
    autoSnapshot.enable = true;
  };
  disko.devices = {
    disk = {
      nvme0n1 = {
        # nvme format --lbaf=1 /dev/nvme0n1
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
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
              size = "128G";
              content = {
                type = "swap";
                randomEncryption = true;
              };
            };
            l2arc = {
              size = "100%";
            };
          };
        };
      };
    } // (lib.genAttrs [
      # DOA disk: 4BHH758H
      "/dev/disk/by-id/ata-ST18000NT001-3NF101_ZVTDQ6XT"
      "/dev/disk/by-id/ata-WDC_WD181KFGX-68AFPN0_3MGZ074U"
      "/dev/disk/by-id/ata-ST18000NT001-3NF101_ZVTE1225"
      "/dev/disk/by-id/ata-ST18000NT001-3NF101_ZVTE1FN5"
      "/dev/disk/by-id/ata-WDC_WD181KFGX-68AFPN0_4BHDGUYH"
      "/dev/disk/by-id/ata-WDC_WD181KFGX-68AFPN0_4BHGZA8H"
      "/dev/disk/by-id/ata-WDC_WD181KFGX-68AFPN0_4BHDRURH"
    ] (device: {
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
              pool = "zpool";
            };
          };
        };
      };
    }));
    zpool.zpool = {
      type = "zpool";
      mode = "raidz2";
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
        # mountpoint = "none";
        encryption = "on";
        keyformat = "passphrase";
      };
      mountpoint = "/";
      datasets = {
        nix = {
          type = "zfs_fs";
          options = {
            atime = "off";
            "com.sun:auto-snapshot" = "false";
          };
        };
        var = {
          type = "zfs_fs";
          options."com.sun:auto-snapshot" = "true";
        };
        home = {
          type = "zfs_fs";
          options = {
            "com.sun:auto-snapshot" = "true";
            normalization = "formD";
          };
        };
        "home/quentin" = {
          type = "zfs_fs";
        };
        media = {
          type = "zfs_fs";
          options = {
            recordsize = "1M";
            mountpoint = "/srv/media";
            secondarycache = "metadata";
            "com.sun:auto-snapshot" = "true";
            normalization = "formD";
          };
        };
        "media/media1e" = {
          type = "zfs_fs";
        };
      };
    };
  };
}
