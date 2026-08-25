{ lib, ... }:
let
  name = "tank";
  zfsDisks = [
    "/dev/disk/by-id/ata-ST18000NM000J-2TV103_ZR50AP85"  # wwn-0x5000c500c7e53b03
    "/dev/disk/by-id/ata-ST18000NT001-3NF101_ZVTDQ6XT"   # wwn-0x5000c500e86f57fb
    "/dev/disk/by-id/ata-ST18000NT001-3NF101_ZVTE1225"   # wwn-0x5000c500e8877637
    "/dev/disk/by-id/ata-ST18000NT001-3NF101_ZVTE1FN5"   # wwn-0x5000c500e878a0f0
    "/dev/disk/by-id/ata-ST18000NM000J-2TV103_ZR523E8A"  # wwn-0x5000c500db6b38b0
    "/dev/disk/by-id/ata-WDC_WD181KFGX-68AFPN0_4BHDGUYH" # wwn-0x5000cca2b6d3c3a7
    "/dev/disk/by-id/ata-WDC_WD181KFGX-68AFPN0_4BHDRURH" # wwn-0x5000cca2b6d3e1a8
    "/dev/disk/by-id/ata-WDC_WD181KFGX-68AFPN0_4BHGZA8H" # wwn-0x5000cca2b6d4e68f
  ];
  deviceToDiskoName = device: lib.last (lib.splitString "_" device);
in {
  disko.devices = {
    disk = lib.genAttrs' zfsDisks (device: lib.nameValuePair (deviceToDiskoName device) {
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
    });
    zpool.${name} = {
      type = "zpool";
      mode.topology = {
        type = "topology";
        vdev = [{
          mode = "raidz2";
          members = map deviceToDiskoName zfsDisks;
        }];
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
        mountpoint = "/tank";
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
