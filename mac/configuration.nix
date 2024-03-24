{ config, pkgs, lib, self, home-manager, deploy-rs, ... }:

{
  imports = [
    ./perl.nix
    ./python.nix
  ];

  environment.shells = with pkgs; [ bashInteractive ];

  nixpkgs.overlays = lib.mkAfter [
    (final: prev: {
      openssh = final.openssh_gssapi;
      gnuplot = prev.gnuplot.override {
        aquaterm = true;
        withCaca = true;
        withLua = true;
        withWxGTK = true;
      };
      #mesa = final.mesa23_3_0_main;
      zig_0_11 = prev.zig_0_11.overrideAttrs (old: {
        cmakeFlags = (old.cmakeFlags or []) ++ [
          "-DZIG_HOST_TARGET_TRIPLE=x86_64-macos.10.15"
        ];
      });
      ncdu = final.ncdu_1;
    })
  ];
  nixpkgs.config.permittedInsecurePackages = [
    # CVE-2023-28531 only affects ssh-add with smartcards.
    "openssh-with-gssapi-9.0p1"
  ];

  programs.macfuse.enable = true;

  programs.wireshark.package = pkgs.wireshark-qt5;

  environment.systemPackages = with pkgs; [
    # Block devices
    f3
    #unsupported gptfdisk
    simg2img

    # Filesystems
    gvfs

    # Development
    #carthage
    #cctools
    #clang
    #why cmake
    #unsupported createrepo_c
    #elftoolchain
    #why gcc9
    #why gdb
    #why imake
    julia-bin
    #ld64
    lua
    #mlir-14
    mono
    #broken octaveFull # build error from CFURL.h with sdk 11.0
    pipenv
    #unsupported rpm
    ruby
    sloccount
    sourceHighlight

    # Multimedia
    #dvdrw-tools
    #mpeg2vidcodec
    #mpgtx
    pulseaudio

    # Other devices
    #blueutil
    libftdi1
    #unsupported lirc
    minicom
    #tuntaposx
    #unsupported usbutils
    #unsupported xsane

    # Database
    unstable.mariadb_1011.client
    mdbtools
    postgresql

    # Network
    #unsupported aircrack-ng
    #aget
    #barnowl
    #bitchx
    #why chrony
    #csshX
    #already curl
    krb5
    #unsupported ldapvi
    #lft
    mtr  # TODO: setuid wrapper
    #ntpsec
    #unsupported nx-libs
    openssh
    #already openssl
    #collision openssl_1_1
    openvpn
    #rlpr
    #unsupported traceroute
    # TODO: Separate linkzone into its own package and/or use subPackages to limit what is built
    (runCommandLocal "linkzone-api" {} ''
      mkdir -p $out/bin
      ln -s ${pkgs.callPackage ../workshop/go {}}/bin/linkzone-api $out/bin/
    '')
    (writeShellScriptBin "hass-cli" ''
      export HASS_SERVER=https://homeassistant.isz.wtf
      export HASS_TOKEN=$(${python3Packages.keyring}/bin/keyring get $HASS_SERVER "")
      exec ${home-assistant-cli}/bin/hass-cli "$@"
    '')

    # Performance monitoring
    btop
    telegraf
    zenith

    # Security
    #broken fcrackzip
    gnupg
    metasploit

    # Shell utilities
    ack
    #backdown
    brotli
    bsdiff
    cabextract
    coreutils
    #cwdiff
    dasel
    debianutils
    (fortune.override {
      withOffensive = true;
    })
    fd
    feedgnuplot
    file-rename
    gcab
    gnutar
    units
    htmlq
    jc
    (pkgs.runCommand "jmespath-jp" {} ''
      mkdir -p $out/bin
      cp ${jp}/bin/jp $out/bin/jmespath
    '')
    #already jq
    json-plot
    less
    libzip
    lzip
    lzma
    #macutil
    moreutils
    most
    ncdu
    p7zip
    pigz
    pixz
    pv
    renameutils
    ripgrep
    rlwrap
    #screenresolution
    sl
    terminal-notifier
    tmate
    tmux
    libuchardet
    unrar
    vbindiff
    vttest
    xdelta
    xmlstarlet
    xqilla
    yj
    yq
    #unsupported gnome.zenity

    # Science
    #funtools
    gdal
    gnuplot
    graphviz

    # Productivity
    contacts
    #broken haskellPackages.pandoc-citeproc
    #unsupported qgis
    #insecure wkhtmltopdf
    #insecure xpdf

    # Games
    #fizmo
    #frobtads
    frotz

    # GUI
    unstable.alacritty
    #Chmox
    #unsupported evince
    #unsupported gnome.gnome-keyring
    gnome-online-accounts
    gtk-vnc
    unstable.inkscape
    #inkscape-app
    #buildfail kicad
    pidgin
    spice-gtk
    tigervnc
    #insecure tightvnc
    #unsupported turbovnc
    #unsupported realvnc-vnc-viewer
    #broken webkitgtk

    # Editors
    emacsPackages.cask

    # MacAthena
    #hesiod
    #macathena-add
    #macathena-alpine-config
    #macathena-athrun
    #macathena-base
    #macathena-clients
    #macathena-delete
    #macathena-discuss
    #macathena-discuss-ng
    #macathena-gathrun
    #macathena-hes
    #macathena-kerberos-config
    #macathena-locker-support
    #macathena-machtype
    #macathena-moira
    #macathena-msmtp
    #macathena-pyhesiodfs
    #macathena-shell-config
    #macathena-standard
    #macathena-xcluster
    #unsupported openafs
    #openafs-signed-kext
    #remctl
    #zephyr

    # Packages from macports
    libcanberra
    poly2tri-c
    #subversion-perlbindings-5.28
    #already texinfo
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

  services.xserver = {
    enable = true;
  };

  services.nix-daemon.enable = true;
  nix.settings = {
    builders = "@/etc/nix/machines";
    bash-prompt-prefix = "(nix:$name)\\040";
    trusted-users = [ "root" "quentin" ];
  };
  nix.distributedBuilds = true;
  nix.buildMachines = [{
    hostName = "workshop.isz.wtf";
    publicHostKey = ''
      c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSU42REcyMDkyMzdzbkVpcEh0WUNLSlFReTJMS29FVllNWVRXTVA1V2NpL0ogcm9vdEB3b3Jrc2hvcAo=
    '';
    sshUser = "ssh-ng://root";
    sshKey = "/Users/quentin/.ssh/id_rsa";
    systems = [
      "aarch64-linux"
      "x86_64-linux"
    ];
  }];

  system.stateVersion = 4;

  users.users.quentin = {
    description = "Quentin Smith";
    uid = 501;
    home = "/Users/quentin";
    shell = "/run/current-system/sw/bin/bash";
  };

  fonts.fonts = with pkgs; [
    monaco-nerd-fonts
  ];

  home-manager.users.quentin = {
    home.stateVersion = "22.11";

    services.clamav.updater.enable = true;

    isz.quentin.enable = true;

    programs.atuin.settings.sync_address = "https://atuin.isz.wtf";

    programs.alacritty = {
      enable = true;
      package = pkgs.unstable.alacritty;
      settings = {
        font.normal.family = "Monaco Nerd Font";
        font.size = 10;
        font.offset = { x = 1; y = 1; };
        draw_bold_text_with_bright_colors = true;
        colors.primary.background = "0x000000";
        colors.primary.foreground = "0xeaeaea";
        colors.cursor.cursor = "0x4d4d4d";
        colors.normal = {
          black =   "0x000000";
          red =     "0xd54e53";
          green =   "0xb9ca4a";
          yellow =  "0xe6c547";
          blue =    "0x7aa6da";
          magenta = "0xc397d8";
          cyan =    "0x70c0ba";
          white =   "0xeaeaea";
        };
        colors.bright = {
          black =   "0x666666";
          red =     "0xff3334";
          green =   "0x9ec400";
          yellow =  "0xe7c547";
          blue =    "0x7aa6da";
          magenta = "0xb77ee0";
          cyan =    "0x54ced6";
          white =   "0xffffff";
        };
        bell = {
          duration = 100;
          color = "0x888888";
        };
        window.padding = { x = 2; y = 2; };
        window.opacity = 0.85;
        window.decorations = "full";
        window.option_as_alt = "Both";
        selection.save_to_clipboard = false;
        mouse_bindings = [
          { mouse = "Middle"; action = "PasteSelection"; }
        ];
        key_bindings = [
          { key = "N"; mods = "Command"; action = "SpawnNewInstance"; }
          { key = "G"; mods = "Control"; mode = "Search"; action = "SearchCancel"; }
        ];
      };
    };

    programs.mpv.package = pkgs.nixpkgs-23_05.mpv;

    # .emacs
    # .gnuradio/config.conf
    # .influxdbv2/configs
    # .ipython/profile_default/ipython_config.py
    # .irssi/config
    # .ldapvirc
    # .meetings
    # .ncftp/bookmarks
    # .netrc
    # .offlineimaprc
    # .owl/startup
    # .password-store
    # .pinerc
    # .sheepshaver_prefs
    # .snmp/mibs/*
    # .spacemacs
    # .subversion/auth
    # .xastir/config/
    # .xlog
    # .zephyr.subs

    home.file."Library/Application Support/ngrok/ngrok.yml".text = let
      secrets = builtins.fromTOML (builtins.readFile ./ngrok-secrets.env);
    in lib.generators.toYAML {} {
      version = "2";
      authtoken = secrets.NGROK_AUTHTOKEN;
      tunnels = {
        "8000" = {
          proto = "http";
          addr = 8000;
        };
        "8080" = {
          proto = "http";
          addr = 8080;
        };
      };
    };

    programs.password-store.settings = {
      PASSWORD_STORE_DIR = "${config.users.users.quentin.home}/.password-store";
    };

    targets.darwin.defaults = {
      NSGlobalDefaults = {
        AppleInterfaceStyle = "Dark";
        AppleShowAllExtensions = true;
        AppleSpacesSwitchOnActivate = false;
        AppleMeasurementUnits = "Inches";
        AppleMetricUnits = false;
        AppleTemperatureUnit = "Fahrenheit";

        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticDashSubstitutionEnabled = true;
        NSAutomaticPeriodSubstitutionEnabled = false;
        NSAutomaticQuoteSubstitutionEnabled = true;
        NSAutomaticSpellingCorrectionEnabled = false;
        NSAutomaticTextCompletionEnabled = true;
        WebAutomaticSpellingCorrectionEnabled = false;

        NavPanelFileListModeForOpenMode = 2;
        NavPanelFileListModeForSaveMode = 2;

        "com.apple.mouse.scaling" = "1.5";
        "com.apple.scrollwheel.scaling" = 0;
      };
      "com.apple.dock" = {
        autohide = false;
        magnification = true;
        orientation = "left";
        "wvous-bl-corner" = 10;
        "wvous-bl-modifier" = 0;
        "show-recents" = false;
      };
    };

    programs.bash = {
      shellAliases = {
        mit-kinit = "kinit";
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
        cyberchef = "open ${pkgs.cyberchef}/share/cyberchef/index.html";
        # TODO: Make cross-platform
        signal-sqlite = ''
          (cd ~/"Library/Application Support/Signal" && ${pkgs.sqlcipher}/bin/sqlcipher -init <(cat config.json | ${pkgs.jq}/bin/jq -r '"PRAGMA key = \"x'"'"'\(.key)'"'"'\";"') sql/db.sqlite)
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

        # . /opt/local/share/nvm/init-nvm.sh
      '';
    };
  };
}
