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
}
