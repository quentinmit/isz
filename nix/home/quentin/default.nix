{ config, lib, pkgs, ... }:
{
  options = {
    isz.quentin = lib.mkEnableOption "User environment for quentin";
  };
  config = lib.mkIf config.isz.quentin (lib.mkMerge [
    {
      home.packages = with pkgs; [
        youtube-dl
        yt-dlp
      ];
      programs.mpv = {
        enable = true;
        bindings = {
          PGDWN = "seek -600";
          PGUP = "seek 600";
          "Shift+PGDWN" = "add chapter -1";
          "Shift+PGUP" = "add chapter 1";

          KP1 = "add video-rotate -90";
          KP2 = "add video-pan-y -0.01";
          KP3 = "add video-rotate +90";
          KP4 = "add video-pan-x +0.01";
          KP5 = "set video-pan-x 0; set video-pan-y 0; set video-zoom 0";
          KP6 = "add video-pan-x -0.01";
          KP7 = "add video-zoom -0.01";
          KP8 = "add video-pan-y +0.01";
          KP9 = "add video-zoom +0.01";
          b = "osd-msg script-message curves-brighten-show";
          y = "osd-msg script-message curves-cooler-show";
          c = "script_message show-clock";
        };
      };
      xdg.configFile."youtube-dl/config".text = ''
        --netrc
      '';
      xdg.configFile."yt-dlp/config".text = ''
        --ap-mso Spectrum
        --netrc
      '';
    }
    {
      home.packages = [
        pkgs.exiftool
      ];
      home.file.".ExifTool_config".text = ''
        %Image::ExifTool::UserDefined::Options = (
            LargeFileSupport => 1,
        );
      '';
    }
    {
      programs.git = {
        package = pkgs.gitFull;
        lfs.enable = true;
      };
    }
    {
      home.file.".gdbinit".text = ''
        set history filename ~/.gdb_history
        set history save on
      '';
    }
    {
      programs.gpg = {
        enable = true;
        settings = rec {
          ask-cert-level = true;
          default-key = "1C71A0665400AACD142EB1A004EE05A8FCEFB697";
          encrypt-to = default-key;
          no-comments = false;
          no-emit-version = false;
          keyid-format = "long";
          no-symkey-cache = false;
        };
      };
    }
    {
      programs.ssh = {
        enable = true;
        extraConfig = (lib.optionalString (pkgs.openssh.pname == "openssh-with-gssapi") ''
          GSSAPIAuthentication yes
          GSSAPIKeyExchange yes
        '') + ''
          PubkeyAcceptedKeyTypes +ssh-dss,ssh-rsa
        '';
        matchBlocks."hercules.comclub.org" = {
          user = "quentins";
          proxyJump = "atlas.comclub.org";
        };
        matchBlocks."sipb-isilon-*" = {
          extraOptions.HostKeyAlgorithms = "+ssh-dss";
        };
        matchBlocks."mattermost.mit.edu" = {
          hostname = "mattermost.mit.edu";
        };
      };
    }
    {
      home.packages = with pkgs; [
        net-snmp
      ];
      home.file.".snmp/snmp.conf".text = ''
        mibAllowUnderline yes
      '';
    }
    {
      # kdo / krootssh
      programs.kdo.enable = true;
      programs.kdo.args = "-r7d -F";
      programs.bash = {
        shellAliases = {
          krootrsync = ''kdo ''${ATHENA_USER:-$USER}/root@ATHENA.MIT.EDU rsync -e 'ssh -o "GSSAPIDelegateCredentials no"' '';
        };
      };
    }
    (lib.mkIf (pkgs.stdenv.isDarwin && config.programs.bash.enableCompletion) {
      programs.bash.profileExtra = ''
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

        complete -F _open open
      '';
    })
  ]);
}