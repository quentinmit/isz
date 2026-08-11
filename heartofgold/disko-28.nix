{ lib, ... }:
{
  # FIXME: Exclude USB-connected drive that doesn't support SMART to prevent hangs.
  isz.telegraf.smart.excludes = ["/dev/sdn"];

  disko.devices = let
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
              pool = "zpool28";
            };
          };
        };
      };
    }));
    zpool.zpool28 = {
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
      datasets = {
        placeholder = {
          type = "zfs_fs";
        };
      };
    };
  };
}
