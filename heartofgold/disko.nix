{ config, lib, ... }:
{
  imports = [
    ./disko-28.nix
  ];
  services.zfs = {
    autoScrub.enable = true;
    autoSnapshot.enable = false;
  };
  boot = let
    names = [
      "zpool"
      "zpool/backup"
      "zpool/heartofgold"
    ];
  in {
    zfs.requestEncryptionCredentials = names;
    zfs.pools.zpool.devNodes = "/dev/disk/by-partlabel";
    initrd.clevis = {
      enable = true;
      devices = lib.genAttrs names (_: { secretFile = "${./zpool.jwe}"; });
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
