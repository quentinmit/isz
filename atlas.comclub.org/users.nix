{ lib, ... }:
let
  users = {
    quentin = {
      isNormalUser = true;
      description = "Quentin Smith";
      extraGroups = [
        "wheel"
        "adm"
        "dialout"
        "video"
        "plugdev"
        "wireshark"
      ];
    };
    ginas = {
      isNormalUser = true;
      description = "Gina Smith";
    };
    phillips = {
      isNormalUser = true;
      description = "Phillip Smith";
    };
  };
in {
  imports = [
    ./quentin.nix
  ];
  disko.devices.zpool.zpool.datasets = lib.genAttrs' (builtins.attrNames users) (name: lib.nameValuePair "home/${name}" {
    type = "zfs_fs";
  });
  users.users = users;
}
