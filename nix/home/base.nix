{ config, pkgs, lib, self, ... }@args:
let
  inherit (pkgs.stdenv) isLinux;
in {
  config = {
    programs.home-manager.enable = true;

    targets.genericLinux.enable = !(args ? osConfig) && pkgs.stdenv.hostPlatform.isLinux;

    nix.registry.isz.flake = self;

    home.packages = import ../modules/base/packages.nix { inherit pkgs; };

    # ~/.gitconfig and ~/.config/git/ignore
    programs.git = {
      enable = true;
      ignores = [
        "*~"
        ''\#*#''
        ".#*"
        ".ipynb_checkpoints"
        "__pycache__"
      ];
      userName = "Quentin Smith";
      userEmail = lib.mkDefault "quentin@mit.edu";
      aliases = {
        up = "pull --rebase";
        k = "log --graph --abbrev-commit --pretty=oneline --decorate";
        log-json = let
          format = ''"%h": {%n  "commit": "%H",%n  "author": "%an <%ae>",%n  "date": "%ad",%n  "message": "%B"%n},'';
        in lib.escapeShellArgs ["log" "--pretty=format:${format}"];
      };
      extraConfig = {
        color.ui = "auto";
        url = {
          "git@github.com:".pushInsteadOf = [
            "https://github.com/"
            "git://github.com/quentinmit/"
          ];
          "git@github.mit.edu:".insteadOf = "https://github.mit.edu/";
          "git@gitlab.com:".pushInsteadOf = "https://gitlab.com/";
        };
      };
    };

    programs.bash = rec {
      enable = true;
      enableCompletion = true;
      historyFileSize = 100000;
      historySize = historyFileSize;
      shellAliases = {
        nix-diff-system = "${pkgs.nix-diff}/bin/nix-diff $(nix-store -qd $(ls -dtr /nix/var/nix/profiles/*-link | tail -n 2))";
        pbcopy = lib.mkIf isLinux ''${pkgs.xsel}/bin/xsel --clipboard --input'';
        pbpaste = lib.mkIf isLinux ''${pkgs.xsel}/bin/xsel --clipboard --output'';
      };
    };

    programs.lesspipe.enable = true;

    programs.dircolors = {
      enable = true;
      enableBashIntegration = true;
    };

    home.file.".screenrc".text = ''
      defscrollback 100000
      term screen-256color
      unsetenv TERM_SESSION_ID
    '';

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
      # Store cache files in ~/.cache/direnv instead of ./.direnv
      stdlib = ''
        : ''${XDG_CACHE_HOME:=$HOME/.cache}
        declare -A direnv_layout_dirs
        direnv_layout_dir() {
          echo "''${direnv_layout_dirs[$PWD]:=$(
            local hash="$(sha1sum - <<<"''${PWD}" | cut -c-7)"
            local path="''${PWD//[^a-zA-Z0-9]/-}"
            echo "''${XDG_CACHE_HOME}/direnv/layouts/''${hash}''${path}"
          )}"
        }
      '';
    };

    programs.readline = {
      enable = true;

      variables.completion-ignore-case = true;
    };
  };
}
