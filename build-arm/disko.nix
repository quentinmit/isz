{ lib, pkgs, config, ... }:
{
  boot.initrd.systemd.services.unlock = {
    path = with pkgs; [
      clevis
      curl
      cryptsetup
      luksmeta
      gnused
      tpm2-tools
      jose
      libpwquality
      coreutils
      gnugrep
      bash
    ];
    enable = true;
    unitConfig.Description = "Unlock root with clevis";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      ExecStart = "${pkgs.clevis}/bin/clevis luks unlock -d ${config.disko.devices.disk.nvme0n1.content.partitions.luks.device} -n ${config.disko.devices.disk.nvme0n1.content.partitions.luks.name}";
    };
    unitConfig.DefaultDependencies = false;
    wants = ["network-online.target"];
    after = ["network-online.target" "cryptsetup-pre.target" "dev-nvme0n1p3.device"];
    requires = ["dev-nvme0n1p3.device"];
    requiredBy = ["cryptsetup.target"];
    before = ["cryptsetup.target"];
  };

  disko.devices = {
    disk.nvme0n1 = {
      type = "disk";
      device = "/dev/nvme0n1";
      imageSize = "64G";
      content = {
        type = "gpt";
        postCreateHook = let
          uboot = "${pkgs.unstable.ubootOrangePi5Max}/u-boot-rockchip.bin";
        in ''
          dd if=${uboot} of=${config.disko.devices.disk.nvme0n1.content.partitions.loader1.device}
        '';
        partitions = {
          # https://opensource.rock-chips.com/wiki_Partitions
          loader1 = {
            priority = 1;
            start = "64s";
            end = "+16M";
          };
          ESP = {
            priority = 2;
            size = "8G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = ["fmask=0027" "dmask=0027"];
            };
          };
          luks = {
            priority = 4;
            size = "100%";
            content = {
              type = "luks";
              name = "crypted";
              settings.allowDiscards = true;
              extraFormatArgs = ["--hw-opal-only"];
              content.type = "lvm_pv";
              content.vg = "vg";
            };
          };
        };
      };
    };
    lvm_vg.vg = {
      type = "lvm_vg";
      lvs.swap = {
        size = "32G";
        content.type = "swap";
      };
      lvs.zfs = {
        size = "100%";
        content.type = "zfs";
        content.pool = "zpool";
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
        "var/lib" = {
          type = "zfs_fs";
          mountpoint = "/var/lib";
        };
        "var/tmp" = {
          type = "zfs_fs";
          mountpoint = "/var/tmp";
          options."com.sun:auto-snapshot" = "false";
        };
        home = {
          type = "zfs_fs";
          options = {
            "com.sun:auto-snapshot" = "true";
            normalization = "formD";
          };
        };
      };
    };
  };
}
