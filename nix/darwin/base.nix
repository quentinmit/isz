{ lib, pkgs, config, home-manager, ... }:

{
  imports = [
    ../modules/base/common.nix
    home-manager.darwinModules.home-manager
  ];
}
