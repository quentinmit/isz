{ config, pkgs, lib, ... }:

{
  home-manager.users.quentin = lib.mkMerge [
    {
      home.stateVersion = "24.05";

      isz.base = true;
      isz.graphical = true;
      isz.quentin.multimedia = true;
      isz.plasma.enable = true;

      services.baloo.excludeFolders = [
        # Don't index Electron folders
        "$HOME/.config/"
        "$HOME/.cache/"
        "$HOME/.local/share/"
        "$HOME/.local/state/"
        "$HOME/.zoom/"
        "$HOME/hog-data/"
      ];


      home.packages = with pkgs; [
        zoom-us
        google-chrome
      ];
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
