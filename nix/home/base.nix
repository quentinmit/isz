{ config, pkgs, lib, self, ... }@args:
let
  inherit (pkgs.stdenv) isLinux;
in {
  options = {
    isz.base = lib.mkEnableOption "base interactive user configuration";
    isz.graphical = lib.mkEnableOption "prefer graphical software";
  };
  config = lib.mkIf config.isz.base {
    programs.home-manager.enable = true;

    targets.genericLinux.enable = !(args ? osConfig) && pkgs.stdenv.hostPlatform.isLinux;

    nix.registry = lib.mkIf (!(args ? osConfig)) {
      isz.flake = self;
    };

    home.packages = import ../modules/base/packages.nix { inherit pkgs; inherit (config.isz) graphical; } ++ [
      (lib.lowPrio pkgs.python3Packages.pygments) # for lesspipe
    ];

    programs.vim = {
      enable = true;
      plugins = [
        pkgs.vimPlugins.vim-nix
      ];
      extraConfig = ''
        syntax on
      '';
    };

    programs.emacs = {
      extraPackages = epkgs: [
        epkgs.nix-mode
        epkgs.magit
        epkgs.go-mode
        epkgs.yaml-mode
      ];
    };

    # ~/.gitconfig and ~/.config/git/ignore
    programs.git = {
      enable = true;
      ignores = [
        "*~"
        ''\#*#''
        ".#*"
        ".ipynb_checkpoints"
        "__pycache__"
        "*.kate-swp"
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
        init.defaultBranch = "main";
        core.pager = "less -F";
        color.ui = "auto";
        url = {
          "git@github.com:".pushInsteadOf = [
            "https://github.com/"
            "git://github.com/quentinmit/"
          ];
          "git@github.mit.edu:".insteadOf = "https://github.mit.edu/";
          "git@gitlab.com:".pushInsteadOf = "https://gitlab.com/";
        };
        rebase.updateRefs = true;
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

    programs.less.enable = true;
    programs.lesspipe.enable = true;
    home.sessionVariables.LESS = lib.mkDefault "-RM";
    home.sessionVariables.LESSCOLORIZER = "pygmentize -O style=github-dark";

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

    programs.atuin = {
      enable = true;
      enableBashIntegration = true;
      package = pkgs.unstable.atuin;
      flags = [
        "--disable-up-arrow"
      ];
      settings = {
        dialect = "us";
        search_mode = "fulltext";
        filter_mode_shell_up_key_binding = "session";
      };
    };

    programs.bash.initExtra = ''
      function histoff {
        unset HISTFILE
        export -n HISTFILE
        unset preexec_functions
        unset precmd_functions
      }
    '';

    xdg.configFile."pip/pip.conf".text = pkgs.lib.generators.toINI {} {
      global.disable-pip-version-check = true;
    };

    programs.starship = {
      enable = true;
      settings = {
        directory = {
          truncate_to_repo = false;
          truncation_length = 8;
          truncation_symbol = "…/";
          style = "bold cyan";
          before_repo_root_style = "fg:7";
          repo_root_style = "cyan";
        };
        status.disabled = false;
        time.disabled = false;
        git_status = {
          # Don't report stashed
          stashed = "";
          # Report the number of commits ahead or behind.
          ahead = "⇡\${count}";
          diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
          behind = "⇣\${count}";
        };
      };
    };

    home.file.".snmp/snmp.conf".text = ''
      mibdirs +${pkgs.snmp-mibs}/share/snmp/mibs
      mibdirs +${pkgs.cisco-mibs}/v2
    '';
  };
}
