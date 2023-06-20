{ config, pkgs, lib, self, home-manager, deploy-rs,... }:

{
  imports = [
    ./perl.nix
    ./python.nix
  ];

  environment.shells = with pkgs; [ bashInteractive ];

  nixpkgs.overlays = [
    (final: prev: {
      openssh = final.openssh_gssapi;
    })
    deploy-rs.overlay
  ];
  nixpkgs.config.permittedInsecurePackages = [
    # CVE-2023-28531 only affects ssh-add with smartcards.
    "openssh-with-gssapi-9.0p1"
  ];

  programs.macfuse.enable = true;

  programs.wireshark.package = pkgs.wireshark-qt5;

  environment.systemPackages = with pkgs; [
    # Block devices
    ddrescue
    f3
    #unsupported gptfdisk
    simg2img

    # Filesystems
    gvfs
    squashfsTools

    # Nix
    statix
    pkgs.deploy-rs.deploy-rs

    # Development
    arduino-cli
    pkgsCross.arm-embedded.buildPackages.binutils
    # gcc provides info pages that overlap; prioritize one to prevent a conflict message.
    (lib.setPrio 15 pkgsCross.arm-embedded.stdenv.cc)
    pkgsCross.arm-embedded.buildPackages.gdb
    #arm-none-linux-gnueabi-binutils
    pkgsCross.avr.buildPackages.gcc
    pkgsCross.avr.avrlibc
    pkgsCross.mingwW64.buildPackages.binutils
    (lowPrio (pkgs.extend (self: super: {
      threadsCross.model = "win32";
      threadsCross.package = null;
    })).pkgsCross.mingw32.stdenv.cc)
    (lowPrio pkgsCross.mingwW64.stdenv.cc)
    avrdude
    #already binutils
    unstable.bossa
    #carthage
    #cctools
    cdecl
    #clang
    #why cmake
    #unsupported createrepo_c
    cvsps
    dfu-util
    #elftoolchain
    esptool
    fdroidserver
    fpc
    #why gcc9
    #why gdb
    ghc
    gperftools
    #why imake
    #unsupported julia
    #ld64
    lua
    #mlir-14
    mono
    #nodejs15
    #nodejs17
    #why npm6
    #why npm7
    nodePackages.npm
    #nvm
    fnm
    octaveFull
    openocd
    pipenv
    #unsupported rpm
    ruby
    rustc
    cargo
    sloccount
    sourceHighlight
    upx
    yarn

    # (D)VCS
    fossil
    #already git
    git-crypt
    git-secret
    mercurial
    rcs

    # Multimedia
    (ffmpeg-full.override {
      withUnfree = true;
    })
    atomicparsley
    avidemux
    cdparanoia
    codec2
    (dav1d.override {
      withTools = true;
      withExamples = true;
    })
    #unsupported dvdbackup
    #dvdrw-tools
    exiftool
    feh
    #already ffmpeg
    flac
    graphicsmagick_q16
    gsm
    id3lib
    #id3tool
    imagemagickBig
    libde265
    libjpeg
    libraw
    #makeicns
    libicns
    mediainfo
    #unsupported mikmod
    #mpeg2vidcodec
    #mpgtx
    mpv
    opencv
    #unsupported pavucontrol
    pulseaudio
    rav1e
    rawtherapee
    sox
    tsduck
    #broken vapoursynth
    wxSVG
    youtube-dl

    # Radio
    dsd
    dsdcc
    #unsupported fldigi
    #unsupported flrig
    gnuradio
    #already gpsbabel
    gpsbabel-gui
    #unsupported gpsd
    unstable.gqrx-portaudio
    #grig
    hamlib_4
    #already from soapysdr-with-plugins limesuite
    multimon-ng
    #unsupported pothos
    rtl-sdr
    rtl_433
    (rx_tools.override {
      soapysdr = soapysdr-with-plugins;
    })
    #unsupported sdrangel
    soapyhackrf
    (xastir.override {
      rastermagick = imagemagick;
    })

    # Other devices
    android-tools
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
    alpine
    #aget
    axel
    #barnowl
    #bitchx
    #why chrony
    #csshX
    #already curl
    fping
    geoip
    iftop
    inetutils
    influxdb2-cli
    iperf3
    ipmitool
    irssi
    krb5
    #unsupported ldapvi
    #lft
    libidn2
    libpsl
    libupnp
    miniupnpc
    mosh
    mosquitto
    mtr  # TODO: setuid wrapper
    nbd
    ncftp
    nmap
    #ntpsec
    #unsupported nx-libs
    openconnect
    openntpd
    openssh
    #already openssl
    #collision openssl_1_1
    openvpn
    pssh
    #rlpr
    tintin
    #unsupported traceroute
    transmission
    websocat
    termshark

    # Emulation
    bochs
    qemu
    #unsupported winetricks

    # Performance monitoring
    btop
    htop
    pstree
    telegraf
    zenith

    # Security
    binwalk
    capstone
    fcrackzip
    gnupg
    gpgme
    metasploit
    oath-toolkit
    pass
    passExtensions.pass-import
    passExtensions.pass-otp
    passExtensions.pass-update
    passExtensions.pass-genphrase
    passExtensions.pass-checkup
    pass-git-helper
    radare2
    rizin
    sops

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
    file-rename
    gcab
    gnutar
    units
    htmlq
    jc
    jp
    #already jq
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
    yq
    #unsupported gnome.zenity

    # Science
    #funtools
    gdal
    gnuplot
    graphviz

    # Productivity
    antiword
    contacts
    diff-pdf
    figlet
    gspell
    gv
    pandoc
    #broken haskellPackages.pandoc-citeproc
    pdf2svg
    pdftk
    poppler_utils
    pstoedit
    #unsupported qgis
    rubber
    texlive.combined.scheme-full
    unrtf
    #insecure wkhtmltopdf
    wordnet
    #insecure xpdf
    zbar

    # Games
    #fizmo
    #frobtads
    frotz

    # GUI
    unstable.alacritty
    #Chmox
    #unsupported evince
    gimp
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
  nix.package = pkgs.nix;
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

    imports = with self.homeModules; [
      base
      clamav
    ];

    services.clamav.updater.enable = true;

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

    home.file.".ExifTool_config".text = ''
      %Image::ExifTool::UserDefined::Options = (
          LargeFileSupport => 1,
      );
    '';

    programs.git = {
      package = pkgs.gitFull;
      lfs.enable = true;
    };

    home.file.".gdbinit".text = ''
      set history filename ~/.gdb_history
      set history save on
    '';

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

    programs.ssh = {
      enable = true;
      extraConfig = ''
        GSSAPIAuthentication yes
        GSSAPIKeyExchange yes
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

    home.file.".snmp/snmp.conf".text = ''
      mibAllowUnderline yes
    '';

    # .emacs
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
        cyberchef = "open ${pkgs.cyberchef}/share/cyberchef/index.html";
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
