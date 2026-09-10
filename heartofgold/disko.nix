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

  isz.sanoid.enable = true;
  services.sanoid = {
    templates.default.frequently = 0;
    datasets."zpool/heartofgold" = {
      use_template = ["default"];
      recursive = "zfs";
    };
  };
}
