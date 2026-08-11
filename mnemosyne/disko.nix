{
  services.zfs = {
    autoScrub.enable = true;
  };
  disko.devices = {
    disk = {
      vda = {
        type = "disk";
        device = "/dev/vda";
        imageSize = "32G";
        content = {
          type = "gpt";
          partitions = {
            bios = {
              size = "1M";
              type = "EF02"; # BIOS boot partition for grub
              attributes = [ 0 ]; # partition attribute
            };
            ESP = {
              size = "8G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [
                  "defaults"
                  "fmask=0027"
                  "dmask=0027"
                ];
              };
            };
            swap = {
              size = "8G";
              content.type = "swap";
              content.randomEncryption = true;
            };
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "boot";
              };
            };
          };
        };
      };
    };
    zpool.boot = {
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
        };
        nix = {
          type = "zfs_fs";
          # /nix needs a mountpoint so that it will be mounted by the initrd
          mountpoint = "/nix";
          options = {
            atime = "off";
          };
        };
        var = {
          type = "zfs_fs";
          mountpoint = "/var";
          options."com.sun:auto-snapshot" = "true";
        };
        "var/backup".type = "zfs_fs";
        "var/cache".type = "zfs_fs";
        "var/lib" = {
          type = "zfs_fs";
          mountpoint = "/var/lib";
        };
        "var/log" = {
          type = "zfs_fs";
          mountpoint = "/var/log";
        };
        "var/tmp".type = "zfs_fs";
        home = {
          type = "zfs_fs";
          options = {
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
