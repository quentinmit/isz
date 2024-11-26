{ config, lib, pkgs, deploy-rs, ... }:
let
  isAarch64Darwin = pkgs.stdenv.isDarwin && pkgs.stdenv.isAarch64;
  open = if pkgs.stdenv.isDarwin then "open" else "${pkgs.xdg-utils}/bin/xdg-open";
  available = pkg: lib.optional pkg.meta.available pkg;
in {
  options = {
    isz.quentin.enable = lib.mkEnableOption "User environment for quentin";
    isz.quentin.vscode.install = lib.mkOption {
      type = lib.types.bool;
      default = config.isz.quentin.enable;
    };
  };
  imports = [
    ./multimedia.nix
    ./theme.nix
    ./python.nix
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
        drawio
        yeetgif
      ] ++ lib.optionals pkgs.stdenv.isLinux [
        darktable
        digikam
        inkscape-with-extensions
        krita
        scribus
        boxy-svg
        kdePackages.kolourpaint
      ] ++ (available libresprite);
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
      ] ++ lib.optionals pkgs.stdenv.isLinux ([
        freecad
      ]
      ++ (available kicad)
      ++ (available bambu-studio)
      ++ (available orca-slicer)
      );
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
        signing.key = config.programs.gpg.settings.default-key;
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
      ] ++ lib.optionals stdenv.isLinux (
        [
          teensyduino
          fritzing
          platformio
        ] ++ available unstable.arduino-ide
      );
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
      ] ++ available fdroidserver;
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
      ] ++ lib.optionals pkgs.stdenv.isLinux [
        heaptrack
        kcachegrind
      ];
      home.file.".gdbinit".text = ''
        set history filename ~/.gdb_history
        set history save on
      '';
    }
    # Visual Studio Code
    {
      home.packages = with pkgs; lib.mkIf config.isz.quentin.vscode.install [
        (unstable.vscode-with-extensions.override {
          vscodeExtensions = with unstable.vscode-extensions; [
            bbenoist.nix
            golang.go
            ms-python.python
            rust-lang.rust-analyzer
            ms-toolsai.jupyter
            ms-vscode.cpptools-extension-pack
            LoyieKing.smalise
            ms-playwright.playwright
            github.vscode-github-actions
            savonet.vscode-liquidsoap
            ms-vscode.cmake-tools
            ms-vscode.makefile-tools
            ms-vsliveshare.vsliveshare
          ] ++ available unstable.vscode-extensions.Surendrajat.apklab;
        })
      ];
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
    # Emacs
    {
      programs.emacs.extraPackages = epkgs: with epkgs; [
        typescript-mode
      ];
    }
    # Games
    {
      home.packages = with pkgs; [
        gnome.lightsoff
      ] ++ lib.optionals pkgs.stdenv.isLinux [
        bottles
        gnuchess # broken on macOS
        kblocks
        kbounce
        knights
        stockfish
        kmines
        knetwalk
        knavalbattle
        kdePackages.ksudoku
        kdePackages.kbreakout
        kdePackages.palapeli
        kdePackages.kolf
        gnome.aisleriot
        gnome.gnome-mines
        gnome.gnome-sudoku
        gnome.swell-foop
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
        #broken virt-manager-qt
        libguestfs-with-appliance
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
        kaitai-struct-compiler
      ] ++ lib.optionals pkgs.stdenv.isLinux [
        unstable.elf-dissector
        imhex
        okteta
        iaito
        pahole
        dwex
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
        lxi-tools-gui
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
        nanovna-saver
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
        qtpass
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
      programs.plasma.configFile."IJHack/QtPass.conf".General = {
        useGit = true;
        useOtp = true;
        useTemplate = true;
      };
    }
    # Network - SSH
    {
      programs.ssh = {
        enable = true;
        extraOptionOverrides = {
          IgnoreUnknown = "GSSAPI*";
        };
        extraConfig = ''
          GSSAPIAuthentication yes
          GSSAPIKeyExchange yes
          # Use a wildcard so this works on non-DSA ssh as well
          PubkeyAcceptedKeyTypes +ssh-?s?
        '';
        matchBlocks = {
          "hercules.comclub.org" = {
            user = "quentins";
            proxyJump = "atlas.comclub.org";
          };
          "sipb-isilon-*" = {
            extraOptions.HostKeyAlgorithms = "+ssh-?s?";
          };
          "mattermost.mit.edu" = {
            hostname = "mattermost.mit.edu";
          };
          "*.isz.wtf" = {
            match = ''originalhost *.isz.wtf'';
            # no IPv6
            extraOptions.AddressFamily = "inet";
          };
          "mac.isz.wtf" = {
            match = ''originalhost mac.isz.wtf !localnetwork 172.30.96.0/22 exec "${pkgs.knock}/bin/knock icestationzebra.isz.wtf 1337:udp 26678:udp"'';
            hostname = "icestationzebra.isz.wtf";
            port = 2222;
          };
          "heartofgold.isz.wtf" = {
            match = ''originalhost heartofgold.isz.wtf !localnetwork 172.30.96.0/22 exec "${pkgs.knock}/bin/knock icestationzebra.isz.wtf 1337:udp 26678:udp"'';
            hostname = "icestationzebra.isz.wtf";
            port = 10122;
          };
        };
      };
      programs.bash.shellAliases = {
        mosh-mac = ''mosh -4 --server="/Users/quentin/bin/mosh-server-upnp" mac.isz.wtf'';
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
    # Network - browsh
    (lib.mkIf pkgs.stdenv.isLinux {
      programs.browsh = {
        enable = true;
        settings = {
          browsh_supporter = "I have shown my support for Browsh";
        };
      };
    })
    # Network
    {
      home.packages = with pkgs; [
        alpine
        axel
        bmon
        geoip
        httpie
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
        mqttui
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
        bruno
      ] ++ lib.optionals pkgs.stdenv.isLinux [
        netsurf.browser
        qgis-ltr
        remmina
        sockdump
      ];
    }
    # Science
    {
      home.packages = with pkgs; [
        (feedgnuplot.override { gnuplot = gnuplot_gui; })
        gdal
        gnuplot_gui
        graphviz
        labplot
        xdot
      ] ++ lib.optionals pkgs.stdenv.isLinux [
        kgraphviewer
        (if kdePackages.kig.meta.available then kdePackages.kig else kig)
        kstars
        marble
        stellarium
        kdePackages.kalgebra
        kdePackages.kalzium
        kdePackages.step
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
        wv
      ] ++ lib.optionals pkgs.stdenv.isLinux ([
        abiword
        #broken calligra
        kdePackages.ghostwriter
        kdePackages.skanlite
        kdePackages.skanpage
        marktext
        retext
        rnote
        xournalpp
      ] ++ available onlyoffice-bin);
    }
    # Productivity - eBooks
    {
      home.packages = with pkgs;
        lib.optionals pkgs.stdenv.isLinux [
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
        xterm
      ] ++ lib.optionals pkgs.stdenv.isLinux [
        xdotool # broken on macOS
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
        csview
        csvlens
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
        xsv
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
        # Causes problems: kdePackages.konqueror
        kdePackages.filelight
        kdePackages.itinerary
        kdePackages.kalarm
        kdePackages.kcalc
        kdePackages.kcharselect
        kdePackages.kdeconnect-kde
        kdePackages.kfilemetadata
        kdePackages.kfind
        kdePackages.kruler
        kdePackages.partitionmanager
        speedcrunch # scientific calculator
        qalculate-qt
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
    (let
      servers = {
        nix = {
          command = ["${pkgs.unstable.nil}/bin/nil"];
          url = "https://github.com/oxalica/nil";
          highlightingModeRegex = "^Nix$";
        };
        yaml = {
          command = ["${pkgs.yaml-language-server}/bin/yaml-language-server" "--stdio"];
          url = "https://github.com/redhat-developer/yaml-language-server";
          highlightingModeRegex = "^YAML$";
        };
      };
    in lib.mkIf pkgs.stdenv.isLinux {
      programs.kate = {
        enable = true;
        package = pkgs.kdePackages.kate;
        editor.indent.replaceWithSpaces = true;
        lsp.customServers = servers;
      };
      programs.plasma.configFile.katerc = {
        General."Startup Session" = "manual";
        General."Stash new unsaved files" = true;
        General."Stash unsaved file changes" = true;
        project.gitStatusSingleClick = 1; # Show Diff
        project.gitStatusDoubleClick = 3; # Stage/Unstage
        project.gitStatusNumStat = true;
        project.restoreProjectsForSessions = true;
        lspclient.AllowedServerCommandLines = lib.concatStringsSep "," (
          lib.mapAttrsToList
          (name: server: lib.concatStringsSep " " server.command)
          servers
        );
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
