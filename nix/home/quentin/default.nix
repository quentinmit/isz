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
      default = config.isz.quentin.enable && config.isz.graphical;
    };
    isz.quentin.texlive = lib.mkOption {
      type = lib.types.bool;
      default = config.isz.quentin.enable;
    };
  };
  imports = builtins.map (name: ./${name}) (
    builtins.attrNames (
      lib.filterAttrs
        (name: type: type == "regular" && name != "default.nix")
        (builtins.readDir ./.)
    )
  );
  config = lib.mkIf config.isz.quentin.enable (lib.mkMerge [
    {
      isz.base = true;
    }
    # Nix
    {
      home.packages = with pkgs; [
        statix
        (pkgs.extend deploy-rs.overlays.default).deploy-rs.deploy-rs
      ] ++ lib.optionals pkgs.stdenv.isLinux [
        nix-du
      ];
    }
    # 3D Modeling
    (lib.mkIf config.isz.graphical {
      home.packages = with pkgs; [
        openscad-unstable
        gerbv
        f3d
      ] ++ lib.optionals pkgs.stdenv.isLinux ([
        freecad
        meshlab
      ]
      ++ (available kicad)
      ++ (available bambu-studio)
      ++ (available orca-slicer)
      );
      xdg.dataFile."OpenSCAD/libraries/BOSL".source = pkgs.fetchFromGitHub {
        owner = "revarbat";
        repo = "BOSL";
        rev = "v1.0.3";
        hash = "sha256-FHHZ5MnOWbWnLIL2+d5VJoYAto4/GshK8S0DU3Bx7O8=";
        meta.license = lib.licenses.bsd2;
      };
      xdg.dataFile."OpenSCAD/libraries/BOSL2".source = pkgs.fetchFromGitHub {
        owner = "BelfrySCAD";
        repo = "BOSL2";
        rev = "ec929bb4e7366a6892c38ad9ba876978894dbdef";
        hash = "sha256-BdQGYwWsroNaAP9AEojQ6qWbrKutG6U3yMzlBcUPkXQ=";
        meta.license = lib.licenses.bsd2;
      };
      xdg.dataFile."OpenSCAD/libraries/GoPro".source = pkgs.fetchFromGitHub {
        owner = "ridercz";
        repo = "GoProScad";
        rev = "98c0161e58d4d912481cdf280b573563e221b2a7";
        hash = "sha256-TY1qk+AQtg3gD0nftagyZbLmUsJHlGeR7jLkJpKMPjY=";
        meta.license = lib.licenses.mit;
      };
      xdg.dataFile."OpenSCAD/libraries/NopSCADlib".source = pkgs.fetchFromGitHub {
        owner = "nophead";
        repo = "NopSCADlib";
        rev = "v21.34.0";
        hash = "sha256-WaNHG9b09HV5QtSXUqvugdGkZ5Uzjm4nRWipXmEaId8=";
        meta.license = lib.licenses.gpl3Plus;
      };
      xdg.dataFile."OpenSCAD/libraries/Recymbol/library.scad".source = pkgs.fetchurl {
        url = "https://files.printables.com/media/prints/136201/stls/2283997_49a84ad3-2b2a-4281-ae60-85db844003f4/library.scad";
        hash = "sha256-ez94OhQJM3jHH2gKZavu1uryR+LYqsy++ag0jlNTzms=";
      };
    })
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
        dfu-util
        esptool
      ] ++ lib.optionals (!isAarch64Darwin) [
        pkgsCross.arm-embedded.buildPackages.gdb
      ] ++ lib.optionals stdenv.isLinux [
        platformio
      ];
    }
    (lib.mkIf config.isz.graphical {
      home.packages = with pkgs; [
        bossa
        openocd
      ] ++ lib.optionals stdenv.isLinux [
        fritzing
        teensyduino
      ] ++ available arduino-ide;
    })
    # Rust development
    {
      home.packages = with pkgs; [
        # rustup provides rustc and cargo
        cargo-show-asm
        cargo-binutils
        cargo-bloat
        cargo-edit
        cargo-expand
        unstable.cargo-feature
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
        mariadb_114.client
        mdbtools
        postgresql
      ];
    }
    (lib.mkIf config.isz.graphical {
      home.packages = with pkgs; [
        wxsqliteplus
      ];
    })
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
        loccount
      ];
      home.file.".gdbinit".text = ''
        set history filename ~/.gdb_history
        set history save on
      '';
    }
    (lib.mkIf config.isz.graphical {
      home.packages = with pkgs; [
      ] ++ lib.optionals pkgs.stdenv.isLinux [
        heaptrack
        kdePackages.kcachegrind
      ];
    })
    # Visual Studio Code
    {
      home.packages = with pkgs; lib.mkIf config.isz.quentin.vscode.install [
        (vscode-with-extensions.override {
          vscodeExtensions = with vscode-extensions; [
            mkhl.direnv
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
            eclipse-cdt.peripheral-inspector
            eclipse-cdt.cdt-gdb-vscode
            ms-vscode.mock-debug
            #marus25.cortex-debug
            #mcu-debug.debug-tracker-vscode
            #mcu-debug.memory-view
          ] ++ available unstable.vscode-extensions.Surendrajat.apklab;
        })
      ];
      programs.vscode.profiles.default = {
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
    # Emulation
    {
      home.packages = with pkgs; [
        (bochs.override {
          enableSDL2 = config.isz.graphical;
          enableWx = !stdenv.hostPlatform.isDarwin && config.isz.graphical;
          enableX11 = !stdenv.hostPlatform.isDarwin && config.isz.graphical;
        })
      ];
    }
    (lib.mkIf config.isz.graphical {
      home.packages = with pkgs; [
        dosbox
        (lib.lowPrio qemu)  # contains libfdt which conflicts with dtc
        virt-manager
      ] ++ lib.optionals pkgs.stdenv.isLinux [
        _86Box-with-roms
        (if pkgs.stdenv.isx86_64 then libguestfs-with-appliance else libguestfs)
        pcem
        rpcemu
        wineWowPackages.full
        winetricks
      ];
    })
    # Reverse engineering
    {
      home.packages = with pkgs; [
        binwalk
        capstone
        hecate
        hexedit
        radare2
        rizin
        (kaitai-struct-compiler.override (old: lib.optionalAttrs (!config.isz.graphical) {
          openjdk8 = pkgs.openjdk8_headless;
        }))
      ] ++ lib.optionals pkgs.stdenv.isLinux [
        pahole
      ];
    }
    (lib.mkIf config.isz.graphical {
      home.packages = with pkgs; [
        (pkgs.writeShellScriptBin "cyberchef" "${open} ${pkgs.cyberchef}/share/cyberchef/index.html")
        (if ghidra-bin.meta.available then ghidra-bin else ghidra)
      ] ++ lib.optionals pkgs.stdenv.isLinux [
        dwex
        elf-dissector
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
    })
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
    (lib.mkIf config.isz.graphical {
      home.packages = with pkgs; [
        qtpass
      ];
      programs.plasma.configFile."IJHack/QtPass.conf".General = {
        useGit = true;
        useOtp = true;
        useTemplate = true;
      };
    })
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
    (lib.mkIf (pkgs.stdenv.isLinux && config.isz.graphical) {
      programs.browsh = {
        enable = true;
        firefoxPackage = pkgs.unstable.firefox;
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
        knock
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
        (openconnect.override (old: lib.optionalAttrs (!config.isz.graphical) {
          stoken = null;
        }))
        openntpd
        perlPackages.WWWMechanize
        perlPackages.libwwwperl
        pssh
        rclone
        tintin
        websocat
        termshark
        mactelnet
      ] ++ lib.optionals pkgs.stdenv.isLinux [
        sockdump
      ];
      programs.tio = {
        enable = true;
        settings = {
          bp = {
            pattern = "^bp(.+)";
            device = "/dev/tty%m1";
            map = "INLCRNL,ODELBS";
          };
        };
      };
    }
    (lib.mkIf config.isz.graphical {
      home.packages = with pkgs; [
        rdesktop
        transmission_4
        bruno
      ] ++ lib.optionals pkgs.stdenv.isLinux [
        netsurf.browser
        qgis-ltr
        remmina
        kdePackages.krdc
        kvirc
      ] ++ (available mqtt-explorer)
      ++ (available mqttx);
    })
    # Science
    {
      home.packages = with pkgs; let
        gnuplot = if config.isz.graphical then gnuplot_gui else pkgs.gnuplot;
      in [
        (feedgnuplot.override { inherit gnuplot; })
        gdal
        gnuplot
        graphviz
      ];
    }
    (lib.mkIf config.isz.graphical {
      home.packages = with pkgs; [
        labplot
        xdot
      ] ++ lib.optionals pkgs.stdenv.isLinux [
        kgraphviewer
        (if kdePackages.kig.meta.available then kdePackages.kig else libsForQt5.kig) # KDE 6 version is currently broken
        kstars
        kdePackages.marble
        stellarium
        kdePackages.kalgebra
        kdePackages.kalzium
        kdePackages.step
      ];
    })
    # Productivity
    {
      home.packages = with pkgs; [
        antiword
        figlet
        pandoc
        pdf2svg
        poppler_utils
        pstoedit
        unrtf
        wordnet
        ghostscript
        wv
      ];
    }
    (lib.mkIf config.isz.graphical {
      home.packages = with pkgs; [
        diff-pdf
        gspell
        gv
        pdftk
        zbar
      ] ++ lib.optionals pkgs.stdenv.isLinux [
        abiword
        #broken calligra
        kdePackages.ghostwriter
        kdePackages.skanlite
        kdePackages.skanpage
        marktext
        retext
        rnote
        xournalpp
      ] ++ available onlyoffice-bin;
    })
    # Productivity - eBooks
    (lib.mkIf config.isz.graphical {
      home.packages = with pkgs;
        lib.optionals pkgs.stdenv.isLinux [
        calibre
        foliate
        sigil
      ];
    })
    # Productivity - TeX
    (lib.mkIf config.isz.quentin.texlive {
      home.packages = with pkgs; [
        rubber
        texlive.combined.scheme-full
      ] ++ lib.optionals config.isz.graphical [
        texstudio
      ] ++ lib.optionals (pkgs.stdenv.isLinux && config.isz.graphical) [
        apostrophe
        kile
        setzer
        texmaker
        texworks
      ];
    })
    # Utilities - X11
    (lib.mkIf config.isz.graphical {
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
        xlsfonts
        xfontsel
      ]);
    })
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
          command = ["${pkgs.nil}/bin/nil"];
          url = "https://github.com/oxalica/nil";
          highlightingModeRegex = "^Nix$";
        };
        yaml = {
          command = ["${pkgs.yaml-language-server}/bin/yaml-language-server" "--stdio"];
          url = "https://github.com/redhat-developer/yaml-language-server";
          highlightingModeRegex = "^YAML$";
        };
      };
    in lib.mkIf (pkgs.stdenv.isLinux && config.isz.graphical) {
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
