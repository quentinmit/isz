{ config, pkgs, lib, nixpkgs, nixos-avf, ... }:
{
  imports = [
    nixos-avf.nixosModules.avf
  ];

  nixpkgs.hostPlatform = "aarch64-linux";

  system.stateVersion = "25.05";

  avf.defaultUser = "quentin";

  nix.settings.trusted-users = [ "root" "quentin" ];

  users.users.quentin = {
    description = "Quentin Smith";
  };
  home-manager.users.quentin = lib.mkMerge [
    {
      home.stateVersion = "25.05";
      isz.quentin.enable = true;
      isz.quentin.texlive = false; # Massive
      isz.quentin.radio.enable = false; # No point without USB support
    }
  ];
}
