{ config, pkgs, lib, nixpkgs, ... }:

with lib;

{
  imports = [
    "${nixpkgs}/nixos/modules/virtualisation/lxc-container.nix"
  ];

  nixpkgs.hostPlatform = { system = "aarch64-linux"; };

  networking.useDHCP = false;
  networking.interfaces.eth0.useDHCP = true;

  system.stateVersion = "23.05";
}
