{ config, pkgs, lib, ... }:
{
  config = {
    programs.home-manager.enable = true;

    # ~/.gitconfig and ~/.config/git/ignore
    programs.git = {
      enable = true;
      ignores = [
        "*~"
        "*#"
        ".ipynb_checkpoints"
        "__pycache__"
      ];
      userName = "Quentin Smith";
      userEmail = lib.mkDefault "quentin@mit.edu";
      aliases = {
        up = "pull --rebase";
        k = "log --graph --abbrev-commit --pretty=oneline --decorate";
      };
    };

    programs.bash = rec {
      enable = true;
      enableCompletion = true;
      historyFileSize = 100000;
      historySize = historyFileSize;
      shellAliases = {
        nix-diff-system = "${pkgs.nix-diff}/bin/nix-diff $(nix-store -qd $(ls -dtr /nix/var/nix/profiles/*-link | tail -n 2))";
      };
    };
  };
}
