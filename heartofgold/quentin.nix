{ config, pkgs, lib, ... }:

{
  home-manager.users.quentin = lib.mkMerge [
    {
      home.stateVersion = "24.05";

      isz.base = true;
      isz.graphical = true;
      isz.quentin.multimedia = true;
    }
    # Emacs
    {
      programs.emacs = {
        enable = true;
        package = pkgs.emacs;
        extraPackages = epkgs: with epkgs; [
          nix-mode
          magit
          go-mode
          yaml-mode
        ];
      };
    }
  ];
}
