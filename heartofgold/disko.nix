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
    initrd.clevis = {
      enable = true;
      devices = lib.genAttrs names (_: { secretFile = "${./zpool.jwe}"; });
    };
  };
}
