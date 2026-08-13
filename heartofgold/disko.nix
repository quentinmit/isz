{ config, lib, ... }:
{
  imports = [
    ./disko-18.nix
    ./disko-28.nix
  ];
  services.zfs = {
    autoScrub.enable = true;
    autoSnapshot.enable = false;
  };
  boot = let
    root = if config.disko.zpool28.root then config.disko.zpool28.name else config.disko.zpool18.name;
    names = [
      "${root}"
      "${root}/backup"
    ] ++ lib.optionals config.disko.zpool28.root [
      "${root}/heartofgold"
    ];
  in {
    zfs.requestEncryptionCredentials = names;
    initrd.clevis = {
      enable = true;
      devices = lib.genAttrs names (_: { secretFile = "${./zpool.jwe}"; });
    };
  };
  specialisation.zpool28-root.configuration = {
    disko.zpool28.root = true;
  };
  specialisation.zpool28-as-zpool-root.configuration = {
    disko.zpool28.root = true;
    disko.zpool28.name = "zpool";
    disko.zpool18.name = "old";
  };
  specialisation.zpool18-as-old-root.configuration = {
    disko.zpool28.root = false;
    disko.zpool28.name = "zpool";
    disko.zpool18.name = "old";
  };
}
