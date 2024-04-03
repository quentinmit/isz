{ config, lib, pkgs, deploy-rs, ... }:
let
  isAarch64Darwin = pkgs.stdenv.isDarwin && pkgs.stdenv.isAarch64;
  open = if pkgs.stdenv.isDarwin then "open" else "${pkgs.xdg-utils}/bin/xdg-open";
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
      isz.base = true;
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
        audacity
        cdparanoia
        cdrkit
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
        mkvtoolnix
        rav1e
        rtmpdump
        sox
        tsduck
        youtube-dl
        yt-dlp
      ] ++ lib.optionals pkgs.stdenv.isLinux [
        avidemux # https://github.com/iains/gcc-darwin-arm64/issues/3 https://github.com/orgs/Homebrew/discussions/3296
        dvdbackup
        mikmod
        vapoursynth
        vlc
        libsForQt5.kdenlive
        timidity
        vmpk
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
    # Multimedia - PipeWire
    (lib.mkIf pkgs.stdenv.isLinux {
      home.packages = with pkgs; [
        lxqt.pavucontrol-qt
        ncpamixer
        helvum
        qpwgraph
      ];
    })
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
        libjpeg_turbo
        libraw # Replaces dcraw
        opencv
        rawtherapee
        #broken wxSVG
        (if pkgs.stdenv.isDarwin then gimp else gimp-with-plugins)
        libwmf
      ] ++ lib.optionals pkgs.stdenv.isLinux [
        darktable
        digikam
        inkscape-with-extensions
        krita
        scribus
      ];
      home.file.".ExifTool_config".text = ''
        %Image::ExifTool::UserDefined::Options = (
            LargeFileSupport => 1,
        );
      '';
    }
    # 3D Modeling
    {
      home.packages = with pkgs; [
        openscad
        gerbv
        kicad
      ] ++ lib.optionals pkgs.stdenv.isLinux [
        freecad
      ];
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
        tig
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
    # Database development
    {
      home.packages = with pkgs; [
        gobang
        unstable.mariadb_1011.client
        mdbtools
        postgresql
        wxsqliteplus
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
        dtc
        fpc
        ghc
        gperftools
        upx
        sloccount
        loccount
      ];
      home.file.".gdbinit".text = ''
        set history filename ~/.gdb_history
        set history save on
      '';
    }
    {
      programs.vscode = {
        userSettings = {
          "telemetry.enableTelemetry" = false;
          "editor.autoClosingBrackets" = "beforeWhitespace";
          "editor.foldingMaximumRegions" = 50000;
          "editor.formatOnSave" = true;
          "editor.renderWhitespace" = "all";
          "go.useLanguageServer" = true;
          "jupyter.alwaysTrustNotebooks" = true;
          "jupyter.disableJupyterAutoStart" = true;
          "jupyter.jupyterServerType" = "remote";
          #"liveshare.allowGuestDebugControl" = true;
          #"liveshare.allowGuestTaskControl" = true;
          #"liveshare.languages.allowGuestCommandControl" = true;
          #"liveshare.notebooks.allowGuestExecuteCells" = true;
          "nix.formatterPath" = "";
          #"jupyter.insidersChannel" = "weekly";
          #"python.insidersChannel" = "weekly";
          "python.languageServer" = "Pylance";
          "terminal.integrated.macOptionIsMeta" = true;
          "window.zoomLevel" = 1;
          "workbench.editorAssociations" = {
            "*.ipynb" = "jupyter-notebook";
          };
        };
        keybindings = [
          {
            # M-backspace sends ^W by default (?!)
            key = "alt+backspace";
            command = "-workbench.action.terminal.sendSequence";
            when = "terminalFocus";
          }
        ];
      };
    }
    # Gaming
    {
      home.packages = with pkgs; [
        gnuchess
        gnome.lightsoff
      ] ++ lib.optionals pkgs.stdenv.isLinux [
        bottles
        kblocks
        kbounce
        knights
        stockfish
        kmines
        knetwalk
        knavalbattle
        libsForQt5.ksudoku
        libsForQt5.kbreakout
        libsForQt5.palapeli
        gnome.aisleriot
      ];
    }
    # Emulation
    {
      home.packages = with pkgs; [
        bochs
        dosbox
        (lib.lowPrio qemu)  # contains libfdt which conflicts with dtc
        virt-manager
      ] ++ lib.optionals pkgs.stdenv.isLinux [
        virt-manager-qt
        pcem
        _86Box
        _86Box-roms
        rpcemu
        wineWowPackages.full
        winetricks
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
        (pkgs.writeShellScriptBin "cyberchef" "${open} ${pkgs.cyberchef}/share/cyberchef/index.html")
        (if ghidra-bin.meta.available then ghidra-bin else ghidra)
      ] ++ lib.optionals pkgs.stdenv.isLinux [
        imhex
        okteta
        iaito
      ];

      xdg.desktopEntries.cyberchef = lib.mkIf pkgs.stdenv.isLinux {
        name = "CyberChef";
        comment = "The Cyber Swiss Army Knife";
        exec = "${pkgs.xdg-utils}/bin/xdg-open ${pkgs.cyberchef}/share/cyberchef/index.html";
        icon = "${pkgs.cyberchef}/share/cyberchef/images/cyberchef-128x128.png";
        categories = ["Utility"];
      };
    }
    # Hardware
    {
      home.packages = with pkgs; [
        sigrok-cli
        pulseview
        gtkwave
        cutecom
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
        sdrpp
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
        bmon
        geoip
        iftop
        influxdb2-cli
        iperf3
        ipmitool
        irssi
        ldapvi
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
        perlPackages.WWWMechanize
        perlPackages.libwwwperl
        pssh
        rclone
        rdesktop
        tintin
        transmission
        websocat
        termshark
        mactelnet
      ] ++ lib.optionals pkgs.stdenv.isLinux [
        netsurf.browser
        qgis-ltr
        remmina
      ];
    }
    # Science
    {
      home.packages = with pkgs; [
        (feedgnuplot.override { gnuplot = gnuplot_gui; })
        gdal
        gnuplot_gui
        graphviz
        xdot
      ] ++ lib.optionals pkgs.stdenv.isLinux [
        kgraphviewer
      ];
    }
    # Productivity
    {
      home.packages = with pkgs; [
        antiword
        diff-pdf
        figlet
        gspell
        gv
        pandoc
        pdf2svg
        pdftk
        poppler_utils
        pstoedit
        unrtf
        wordnet
        zbar
        ghostscript
      ] ++ lib.optionals pkgs.stdenv.isLinux ([
        libsForQt5.ghostwriter
        marktext
        retext
        rnote
        xournalpp
      ] ++ lib.optional onlyoffice-bin.meta.available onlyoffice-bin);
    }
    # Productivity - eBooks
    {
      home.packages = with pkgs; [
      ] ++ lib.optionals pkgs.stdenv.isLinux [
        calibre
        foliate
        sigil
      ];
    }
    # Productivity - TeX
    {
      home.packages = with pkgs; [
        rubber
        texlive.combined.scheme-full
        texstudio
      ] ++ lib.optionals pkgs.stdenv.isLinux [
        apostrophe
        kile
        setzer
        texmaker
        texworks
      ];
    }
    # Utilities - X11
    {
      home.packages = (with pkgs; [
        xdotool
        xterm
      ]) ++ (with pkgs.xorg; [
        xdpyinfo
        xeyes
        xhost
        xprop
        xrandr
        xset
        xwininfo
      ]);
    }
    # Utilities
    {
      home.packages = with pkgs; [
        ack
        brotli
        bsdiff
        cabextract
        colordiff
        dasel
        debianutils
        (fortune.override {
          withOffensive = true;
        })
        fd
        file-rename
        gcab
        gnutar
        units
        htmlq
        jc
        jless
        (pkgs.runCommand "jmespath-jp" {} ''
          mkdir -p $out/bin
          cp ${jp}/bin/jp $out/bin/jmespath
        '')
        json-plot
        less
        libxml2
        libxslt
        libzip
        lnav
        lzip
        lzma
        moreutils
        most
        ncdu
        p7zip
        perlPackages.JSONXS
        perlPackages.StringShellQuote
        pigz
        pixz
        pv
        renameutils
        ripgrep
        rlwrap
        sharutils
        sl
        tmate
        libuchardet
        unrar
        vbindiff
        vttest
        xdelta
        xmlstarlet
        xqilla
        yazi
        yj
        yq
      ] ++ lib.optionals pkgs.stdenv.isLinux ([
        d-spy
        wl-clipboard
      ] ++ lib.optional (!bustle.meta.broken) bustle);
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
    # Completion for `open` on Darwin
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
    # KDE apps
    (lib.mkIf config.isz.plasma.enable {
      home.packages = with pkgs; [
        kcharselect
        libsForQt5.konqueror
        libsForQt5.kfilemetadata
      ];
    })
    # Konsole
    (lib.mkIf config.isz.plasma.enable {
      programs.plasma = {
        configFile.konsolerc = {
          "Desktop Entry".DefaultProfile = "Quentin.profile";
          General.ConfigVersion = 1;
        };
        dataFile."konsole/Quentin.profile" = {
          General.Name = "Quentin";
          General.Parent = "FALLBACK/";
          General.InvertSelectionColors = true;
          Appearance.ColorScheme = "Quentin";
        };
        dataFile."konsole/Quentin.colorscheme" = {
          General.Description = "Quentin";
          General.Opacity = 0.8;
          Background.Color = "0,0,0";
          BackgroundFaint.Color = "0,0,0";
          # Rest are a copy of Breeze.colorscheme
          General.Anchor = "0.5,0.5";
          General.Blur = false;
          General.ColorRandomization = false;
          General.FillStyle = "Tile";
          General.Wallpaper = "";
          General.WallpaperFlipType = "NoFlip";
          General.WallpaperOpacity = 1;
          Foreground.Color = "252,252,252";
          ForegroundFaint.Color = "239,240,241";
          ForegroundIntense.Color = "255,255,255";
          BackgroundIntense.Color = "0,0,0";
          Color0.Color = "35,38,39";
          Color0Faint.Color = "49,54,59";
          Color0Intense.Color = "127,140,141";
          Color1.Color = "237,21,21";
          Color1Faint.Color = "120,50,40";
          Color1Intense.Color = "192,57,43";
          Color2.Color = "17,209,22";
          Color2Faint.Color = "23,162,98";
          Color2Intense.Color = "28,220,154";
          Color3.Color = "246,116,0";
          Color3Faint.Color = "182,86,25";
          Color3Intense.Color = "253,188,75";
          Color4.Color = "29,153,243";
          Color4Faint.Color = "27,102,143";
          Color4Intense.Color = "61,174,233";
          Color5.Color = "155,89,182";
          Color5Faint.Color = "97,74,115";
          Color5Intense.Color = "142,68,173";
          Color6.Color = "26,188,156";
          Color6Faint.Color = "24,108,96";
          Color6Intense.Color = "22,160,133";
          Color7.Color = "252,252,252";
          Color7Faint.Color = "99,104,109";
          Color7Intense.Color = "255,255,255";
        };
      };
    })
    # Kate
    (lib.mkIf pkgs.stdenv.isLinux {
      home.packages = with pkgs; [
        kate
      ];
      xdg.configFile."kate/lspclient/settings.json".text = lib.generators.toJSON {} {
        servers.nix = {
          command = ["${pkgs.unstable.nil}/bin/nil"];
          url = "https://github.com/oxalica/nil";
          highlightingModeRegex = "^Nix$";
        };
      };
      programs.plasma.configFile.katerc = {
        General."Startup Session" = "manual";
        General."Stash new unsaved files" = true;
        General."Stash unsaved file changes" = true;
        project.gitStatusSingleClick = 1; # Show Diff
        project.gitStatusDoubleClick = 3; # Stage/Unstage
        project.gitStatusNumStat = true;
        project.restoreProjectsForSessions = true;
        lspclient.AllowedServerCommandLines = "${pkgs.unstable.nil}/bin/nil";
      };
    })
    # Signal
    {
      programs.bash.shellAliases.signal-sqlite = let
        root = if pkgs.stdenv.isDarwin
               then "${config.home.homeDirectory}/Library/Application Support/Signal"
               else "${config.xdg.configHome}/Signal";
      in ''
        (cd ${lib.escapeShellArg root} && ${pkgs.sqlcipher}/bin/sqlcipher -init <(cat config.json | ${pkgs.jq}/bin/jq -r '"PRAGMA key = \"x'"'"'\(.key)'"'"'\";"') sql/db.sqlite)
      '';
    }
  ]);
}
