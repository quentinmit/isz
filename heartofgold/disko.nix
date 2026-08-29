{ config, lib, ... }:
{
  imports = [
    ./disko-28.nix
  ];
  services.zfs = {
    autoScrub.enable = true;
    autoSnapshot.enable = false;
  };
  boot = {
    zfs.requestEncryptionCredentials = [
      "zpool"
      "zpool/backup"
      "zpool/heartofgold"
    ];
    zfs.pools.zpool.devNodes = "/dev/disk/by-partlabel";
    initrd.clevis = {
      enable = true;
      devices.zpool.secretFile = "${./zpool.jwe}";
      devices."zpool/heartofgold".secretFile = "${./zpool.jwe}";
      devices."zpool/backup".secretFile = "${./zpool-backup.jwe}";
    };
  };

  services.sanoid = {
    enable = true;
    interval = lib.mkDefault "*:0/15";
    templates.default = {
      frequently = 0;
      hourly = 24;
      daily = 7;
      monthly = 12;
      yearly = 0;
    };
    datasets."zpool/heartofgold" = {
      use_template = ["default"];
      recursive = "zfs";
    };
  };
}
