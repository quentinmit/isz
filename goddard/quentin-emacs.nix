{ config, pkgs, lib, chemacs2nix, ... }:
{
  imports = [
    chemacs2nix.homeModule
  ];
  programs.emacs = {
    enable = true;
    package = pkgs.emacs;
    extraPackages = epkgs: with epkgs; [
      nix-mode
      magit
      go-mode
      yaml-mode
      vterm # For Spacemacs
    ];
    chemacs.profiles.vanilla = {};
    chemacs.profiles.spacemacs = {};
  };
}
