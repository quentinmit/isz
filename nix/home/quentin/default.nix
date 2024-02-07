{ config, lib, pkgs, deploy-rs, ... }:
let
  isAarch64Darwin = (pkgs.stdenv.isDarwin && pkgs.stdenv.isAarch64);
in {
  options = {
    isz.quentin.enable = lib.mkEnableOption "User environment for quentin";
  };
  imports = [
    ./theme.nix
  ];
  config = lib.mkIf config.isz.quentin.enable (lib.mkMerge [
    {
      nixpkgs.overlays = lib.mkAfter [
        deploy-rs.overlay
      ];
    }
    # Nix
    {
      home.packages = with pkgs; [
        statix
        pkgs.deploy-rs.deploy-rs
      ] ++ lib.optionals pkgs.stdenv.isLinux [
        nix-du
      ];
    }
    # Multimedia
    {
      home.packages = with pkgs; [
        atomicparsley
        cdparanoia
        codec2
        (dav1d.override {
          withTools = true;
          withExamples = true;
        })
        flac
        (ffmpeg-full.override {
          withUnfree = true;
        })
        gsm
        id3lib
        #id3tool
        libde265
        mediainfo
        rav1e
        sox
        tsduck
        youtube-dl
        yt-dlp
      ] ++ lib.optionals pkgs.stdenv.isLinux [
        avidemux # https://github.com/iains/gcc-darwin-arm64/issues/3 https://github.com/orgs/Homebrew/discussions/3296
        dvdbackup
        lxqt.pavucontrol-qt
        mikmod
        pavucontrol
        ncpamixer
        vapoursynth
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
    # Imaging
    {
      home.packages = with pkgs; [
        exiftool
        feh
        graphicsmagick_q16
        imagemagickBig
        #makeicns
        libicns
        libjpeg
        libraw
        opencv
        rawtherapee
        #broken wxSVG
      ];
      home.file.".ExifTool_config".text = ''
        %Image::ExifTool::UserDefined::Options = (
            LargeFileSupport => 1,
        );
      '';
    }
    # (D)VCS
    {
      home.packages = with pkgs; [
        cvsps
        fossil
        git-crypt
        git-fullstatus
        git-secret
        mercurial
        rcs
      ];
      programs.git = {
        package = pkgs.gitFull;
        lfs.enable = true;
      };
    }
    # Embedded development
    {
      home.packages = with pkgs; [
        arduino-cli
        pkgsCross.arm-embedded.buildPackages.bintools # arm-none-eabi-{ld,objdump,strings,nm,...}
        # gcc provides info pages that overlap; prioritize one to prevent a conflict message.
        (lib.setPrio 15 pkgsCross.arm-embedded.stdenv.cc)
        #arm-none-linux-gnueabi-binutils
        pkgsCross.avr.buildPackages.gcc
        pkgsCross.avr.avrlibc
        avrdude
        bossa
        dfu-util
        esptool
        openocd
      ] ++ lib.optionals (!isAarch64Darwin) [
        pkgsCross.arm-embedded.buildPackages.gdb
      ];
    }
    # Rust development
    {
      home.packages = with pkgs; [
        # rustup provides rustc and cargo
        cargo-asm
        cargo-binutils
        cargo-bloat
        cargo-edit
        cargo-expand
        cargo-feature
        cargo-generate
        cargo-hf2
        cargo-outdated
        cargo-ui
        probe-rs
      ];
      programs.rustup.enable = true;
      programs.rustup.extensions = [
        "rust-src"
        "rust-analyzer"
        "rust-analysis"
      ];
      programs.rustup.targets = lib.unique [
        pkgs.hostPlatform.config
        "thumbv6m-none-eabi"
        "thumbv7em-none-eabi"
        "thumbv7em-none-eabihf"
        "x86_64-unknown-linux-gnu"
      ];
      #programs.cargo.settings.paths = [
      #  "/Users/quentin/Software/avr-device"
      #];
    }
    # Android development
    {
      home.packages = with pkgs; [
        android-tools
      ] ++ lib.optional fdroidserver.meta.available fdroidserver;
    }
    # Node.js development
    {
      home.packages = with pkgs; [
        nodePackages.npm
        #nodejs15
        #nodejs17
        #why npm6
        #why npm7
        #nvm
        fnm
        yarn
      ];
    }
    # Development
    {
      home.packages = with pkgs; [
        pkgsCross.mingwW64.buildPackages.bintools
        (lowPrio (pkgs.extend (self: super: {
          threadsCross.model = "win32";
          threadsCross.package = null;
        })).pkgsCross.mingw32.stdenv.cc)
        (lowPrio pkgsCross.mingwW64.stdenv.cc)
        #already binutils
        cdecl
        fpc
        ghc
        gperftools
        upx
      ];
      home.file.".gdbinit".text = ''
        set history filename ~/.gdb_history
        set history save on
      '';
    }
    # Emulation
    {
      home.packages = with pkgs; [
        bochs
        qemu
        virt-manager
      ] ++ lib.optionals pkgs.stdenv.isLinux [
        winetricks
        virt-manager-qt
      ];
    }
    # Reverse engineering
    {
      home.packages = with pkgs; [
        binwalk
        capstone
        hecate
        hexedit
        radare2
        rizin
      ] ++ lib.optionals pkgs.stdenv.isLinux [
        imhex
        okteta
      ];
    }
    # Radio
    {
      home.packages = with pkgs; [
        dsd
        dsdcc
        gnuradio
        #already gpsbabel
        gpsbabel-gui
        #grig
        hamlib_4
        #already from soapysdr-with-plugins limesuite
        multimon-ng
        rtl-sdr
        rtl_433
        (rx_tools.override {
          soapysdr = soapysdr-with-plugins;
        })
        soapyhackrf
        xastir
      ] ++ lib.optionals pkgs.stdenv.isLinux [
        csdr
        fldigi
        flrig
        gpsd
        pothos
        sdrangel
      ] ++ lib.optionals (!isAarch64Darwin) [
        unstable.gqrx-portaudio
      ];
    }
    # Security
    {
      home.packages = with pkgs; [
        gpgme
        oath-toolkit
        pass-git-helper
        sops
      ];
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
      programs.password-store = {
        enable = true;
        package = pkgs.pass.withExtensions (exts: with exts; [
          pass-import
          pass-otp
          pass-update
          pass-genphrase
          pass-checkup
        ]);
      };
    }
    # Network - SSH
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
    # Network - SNMP
    {
      home.packages = with pkgs; [
        net-snmp
      ];
      home.file.".snmp/snmp.conf".text = ''
        mibAllowUnderline yes
      '';
    }
    # Network
    {
      home.packages = with pkgs; [
        alpine
        axel
        geoip
        iftop
        inetutils
        influxdb2-cli
        iperf3
        ipmitool
        irssi
        libidn2
        libpsl
        libupnp
        miniupnpc
        mosquitto
        nbd
        ncftp
        ngrok
        nmap
        openconnect
        openntpd
        pssh
        tintin
        transmission
        websocat
        termshark
      ];
    }
    # Kerberos
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
