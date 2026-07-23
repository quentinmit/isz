{
  services.zfs = {
    autoScrub.enable = true;
  };
  # Ensure that the pool is not imported until after local-fs-pre.target, and therefore that the pool is not imported until systemd-hibernate-resume.service has finished.
  # See https://www.freedesktop.org/software/systemd/man/latest/bootup.html#Bootup%20in%20the%20initrd
  boot.initrd.systemd.services.zfs-import-goddard = {
    wants = [
      "local-fs-pre.target"
    ];
    after = [
      "local-fs-pre.target"
    ];
  };
  disko.devices = {
    disk = {
      goddard8t = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-WD_BLACK_SN850X_8000GB_245244800316";
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
                  "fmask=0027"
                  "dmask=0027"
                ];
              };
            };
            swapLuks = {
              size = "96G";
              content = {
                type = "luks";
                name = "cryptedSwap";
                askPassword = true;
                settings = {
                  allowDiscards = true;
                  crypttabExtraOpts = [ "tpm2-device=auto" ];
                };
                #additionalKeyFiles = [ "/tmp/additionalSecret.key" ];
                content = {
                  type = "swap";
                  discardPolicy = "once";
                };
              };
            };
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "goddard";
              };
            };
          };
        };
      };
    };
    zpool.goddard = {
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
        "var/cache".type = "zfs_fs";
        "var/lib" = {
          type = "zfs_fs";
          mountpoint = "/var/lib";
        };
        "var/lib/machines".type = "zfs_fs";
        "var/lib/libvirt".type = "zfs_fs";
        "var/lib/waydroid".type = "zfs_fs";
        "var/log" = {
          type = "zfs_fs";
          mountpoint = "/var/log";
        };
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
        "home/quentin".type = "zfs_fs";
        srv.type = "zfs_fs";
        "srv/vm".type = "zfs_fs";
      };
    };
  };
}
