{ config, pkgs, lib, ... }:

{
  users.users.quentin = {
    openssh.authorizedKeys.keys = config.users.users.root.openssh.authorizedKeys.keys;
  };
  home-manager.users.quentin = lib.mkMerge [
    {
      home.stateVersion = "25.05";

      isz.base = true;
    }
  ];
}
