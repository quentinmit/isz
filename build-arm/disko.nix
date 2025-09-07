{ lib, pkgs, config, ... }:
{
  # Utilities used by `clevis luks`
  boot.initrd.systemd.initrdBin = with pkgs; [
    cryptsetup
    gnused
    gnugrep
    luksmeta
  ];
  boot.initrd.systemd.services.unlock = let
    devUnit = "dev-disk-by\\x2dpartlabel-disk\\x2dnvme0n1\\x2dluks.device";
  in {
    enable = true;
    unitConfig.Description = "Unlock root with clevis";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      ExecStart = "-${pkgs.clevis}/bin/clevis luks unlock -d ${config.disko.devices.disk.nvme0n1.content.partitions.luks.device} -n ${config.disko.devices.disk.nvme0n1.content.partitions.luks.content.name}";
    };
    unitConfig.DefaultDependencies = false;
    wants = ["network-online.target"];
    after = ["network-online.target" "cryptsetup-pre.target" devUnit];
    requires = [devUnit];
    requiredBy = ["cryptsetup.target"];
    before = ["cryptsetup.target" "systemd-cryptsetup@crypted.service"];
  };
  # Allow TRIM
  environment.etc."lvm/lvm.conf".text = ''
    devices/issue_discards = 1
  '';
  # Wait for LUKS before trying to import the pool
  boot.initrd.systemd.services.zfs-import-zpool = {
    after = [ "cryptsetup.target" ];
    wants = [ "cryptsetup.target" ];
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
