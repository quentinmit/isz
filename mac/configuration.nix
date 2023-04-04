{ config, pkgs, lib, home-manager, ... }:

{
  imports = [
    ../nix/modules/base
    ../nix/modules/telegraf
  ];

  environment.systemPackages = with pkgs; [
    statix
    telegraf
    (ffmpeg-full.override {
      nonfreeLicensing = true;
    })
  ];

  programs.bash = {
    enable = true;
    enableCompletion = true;
    interactiveShellInit = ''
      PS1='\h:\W \u\$ '
    '';
  };

  isz.telegraf.enable = true;
  services.telegraf.environmentFiles = [
    ./telegraf.env
  ];

  services.nix-daemon.enable = true;
  nix.package = pkgs.nix;
  nix.settings = {
    bash-prompt-prefix = "(nix:$name)\\040";
  };
  system.stateVersion = 4;

  home-manager.users.quentin = {
    home.stateVersion = "22.11";

    imports = [
      ../nix/home/base.nix
    ];

    programs.git = {
      extraConfig = {
        url = {
          "git@github.com:".pushInsteadOf = "https://github.com/";
          "git@github.mit.edu:".insteadOf = "https://github.mit.edu/";
          "git@gitlab.com:".pushInsteadOf = "https://gitlab.com/";
        };
      };
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
        sync_address = "https://atuin.isz.wtf";
        search_mode = "fulltext";
        filter_mode_shell_up_key_binding = "session";
      };
    };

    programs.bash = {
      shellAliases = {
        mit-kinit = "kinit";
        krootrsync = ''kdo quentin/root@ATHENA.MIT.EDU rsync -e 'ssh -o "GSSAPIDelegateCredentials no"' '';
        xvm-pssh = "kdo quentin/root@ATHENA.MIT.EDU pssh -h ~/lib/xvm-hosts.txt -O GSSAPIDelegateCredentials=no -l root";
        xvm-csshX = "PATH=~/bin:$PATH csshX --login root --ssh ~/bin/mit-ssh $(cat ~/lib/xvm-hosts.txt)";
        xdh-pssh = "kdo quentin/root@ATHENA.MIT.EDU pssh -h ~/lib/xvm-dev-hosts.txt -O GSSAPIDelegateCredentials=no -l root";
        ssh-nokrb = "ssh -o GSSAPIAuthentication=no -o GSSAPIDelegateCredentials=no -o GSSAPIKeyExchange=no";
        emacsclient = "/Applications/Emacs.app/Contents/MacOS/bin/emacsclient";
        kdmesg = ''log show --predicate "processID == 0" --start $(date "+%Y-%m-%d") --debug'';
        log_private = ''sudo log config --mode "private_data:on"'';
        kchrome = ''/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --temp-profile --user-data-dir=$(mktemp -d $TMPDIR/google-chome.XXXXXXX) --no-first-run --auth-server-whitelist="*.mit.edu"'';
        spkg = ''/Applications/Suspicious\ Package.app/Contents/SharedSupport/spkg'';
        pbpaste-html = ''
          osascript -e 'the clipboard as «class HTML»' |   perl -ne 'print chr foreach unpack("C*",pack("H*",substr($_,11,-3)))'
        '';
      };
      bashrcExtra = ''
        #export PATH="/opt/local/libexec/gnubin:$PATH"
        #export PATH="/Users/quentin/go/bin:/Users/quentin/.npm/bin:/usr/local/bin:/opt/local/bin:/opt/local/sbin:/usr/X11/bin:$PATH"
        #export PATH="/Users/quentin/Library/Python/3.10/bin:$PATH"
        #export PATH="/Users/quentin/.cargo/bin:$PATH"
        export GOPATH=/Users/quentin/go
        export JUPYTERLAB_DIR=~/.local/share/jupyter/lab
      '';
      initExtra = ''
        export CDPATH=:~

        . ~/Documents/MIT/SIPB/snippets/kerberos/kdo
        kdo_args=(-r7d -F)

        ec-1e-goodale-torrent() {
          scp "$@" ec-1e-goodale-tv.mit.edu:/srv/media/torrents/watch/ && rm "$@";
        }

        media1e-torrent() {
          scp "$@" media1e.mit.edu:/srv/media/torrents/watch/ && rm "$@";
        }

        function scripts-servers {
            local IFS="|"
            fwm="''${*:-[0-9]+}"
            finger @scripts.mit.edu | sed -E -n -e "1,4d" -e "/^FWM  ($fwm) /, /^[^ ]/ s/  -> ([^:]*):.*/\1/p" | sort -u
        }

        function scripts-csshX {
            PATH=~/bin:$PATH csshX --login root --ssh ~/bin/mit-ssh $(scripts-servers "$@")
        }


        function sipb-noc {
            finger "''${1:-status}"-$COLUMNS@sipb-noc.mit.edu
        }

        function ecmr-vpn {
            sudo bash -c 'openvpn2 --config /Users/quentin/Documents/MIT/EC/ecmr-vpn.cfg --auth-user-pass <(sudo -u quentin pass ecmr | head -2 | tac)'
        }

        function histoff {
          unset HISTFILE
          export -n HISTFILE
          unset preexec_functions
          unset precmd_functions
        }

        # . /opt/local/share/nvm/init-nvm.sh
      '';
      profileExtra = ''
        if ! type _compopt_o_filenames &> /dev/null; then
          _compopt_o_filenames ()
          {
            compopt -o filenames 2>/dev/null
          }
        fi

        # FIXME: Why do some apps not have kMDItemAlternateNames? Missing Info.plist?
        _open_apps_by_name ()
        {
          local IFS='
        ';
          _quote_readline_by_ref "$1" quoted;
          local -a apps;
          apps=($(mdfind -literal "kMDItemContentTypeTree == 'com.apple.application' && kMDItemAlternateNames == '$1*'"));
          if [ ''${#apps[@]} -ne 0 ]; then
            COMPREPLY=($(basename -a -- "''${apps[@]}" | sort -u));
            _compopt_o_filenames;
          fi
        }

        # If compgen ever gains the ability to match case-insensitive against -W, switch to this.
        _open_apps_by_name_slow ()
        {
          local IFS='
        ';
          _quote_readline_by_ref "$1" quoted;
          local -a apps;
          local -a toks;
          apps=($(basename -a -- $(mdfind -literal "kMDItemContentTypeTree == 'com.apple.application'") | sort -u));
          toks=($(compgen -W "''${apps[*]}" "$1"));
          if [ ''${#toks[@]} -ne 0 ]; then
            _compopt_o_filenames;
            COMPREPLY=("''${toks[@]}");
          fi
        }

        _open_apps_by_bundle_id ()
        {
          local IFS='
        ';
          _quote_readline_by_ref "$1" quoted;
          local -a apps;
          local -a toks;
          apps=($(~/bin/list_apps_by_bundle_id | sort -u));
          toks=($(compgen -W "''${apps[*]}" "$1"));
          if [ ''${#toks[@]} -ne 0 ]; then
            _compopt_o_filenames;
            COMPREPLY=("''${toks[@]}");
          fi
        }

        _open ()
        {
          COMPREPLY=();
          local cur prev;
          _get_comp_words_by_ref cur prev;
          case $prev in
            -a)
              _open_apps_by_name "$cur";
              return 0
              ;;
            -b)
              _open_apps_by_bundle_id "$cur";
              return 0
              ;;
          esac;
          if [[ "$cur" == -* ]]; then
            COMPREPLY=($( compgen -W '-a -b -e -t -f -F --fresh -R --reveal -W --wait-apps --args -n --new -j --hide -g --background -h --header' -- "$cur" ));
            return 0;
          fi;
          _filedir
        }

        if [ -f /opt/local/etc/bash_completion ]; then
            complete -F _open open
        fi
      '';
    };
  };
}
