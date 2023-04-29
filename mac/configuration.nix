{ config, pkgs, lib, home-manager, ... }:

{
  imports = [
    ../nix/modules/base
    ../nix/modules/telegraf
    ../nix/modules/xquartz
    ./python.nix
  ];

  environment.shells = with pkgs; [ bashInteractive ];

  nixpkgs.overlays = [
    (final: prev: {
      openssh = final.openssh_gssapi;
    })
  ];

  isz.programs = {
    # Replace with wireshark
    tshark = false;
  };
  environment.systemPackages = with pkgs; [
    statix
    telegraf
    (ffmpeg-full.override {
      nonfreeLicensing = true;
    })
    # Packages from macports
    ack
    #aget
    #unsupported aircrack-ng
    unstable.alacritty
    alpine
    antiword
    #why aom
    arduino-cli
    pkgsCross.arm-embedded.buildPackages.binutils
    pkgsCross.arm-embedded.stdenv.cc
    pkgsCross.arm-embedded.buildPackages.gdb
    #arm-none-linux-gnueabi-binutils
    atomicparsley
    avidemux
    pkgsCross.avr.buildPackages.gcc
    pkgsCross.avr.avrlibc
    avrdude
    axel
    #backdown
    #barnowl
    #already binutils
    binwalk
    #bitchx
    #blueutil
    bochs
    #why boehmgc
    #why boost
    unstable.bossa
    bpytop
    bsdiff
    #already bwm-ng
    #why c-ares
    cabextract
    #why cairomm
    capstone
    #carthage
    emacsPackages.cask
    #cctools
    cdecl
    cdparanoia
    #Chmox
    #why chrony
    #clang
    #why cmake
    codec2
    contacts
    coreutils
    #unsupported createrepo_c
    #csshX
    #why ctop
    #already curl
    cvsps
    #cwdiff
    dasel
    dav1d
    ddrescue
    debianutils
    dfu-util
    diff-pdf
    #unsupported dsd
    #unsupported dsdcc
    #unsupported dvdbackup
    #dvdrw-tools
    #elftoolchain
    esptool
    #unsupported evince
    exiftool
    f3
    fcrackzip
    fd
    fdroidserver
    feh
    #already ffmpeg
    figlet
    #fizmo
    flac
    #unsupported fldigi
    #unsupported flrig
    (fortune.override {
      withOffensive = true;
    })
    fossil
    fpc
    fping
    #frobtads
    frotz
    #funtools
    gcab
    #why gcc9
    gdal
    #why gdb
    gegl
    ghc
    gimp
    #already git
    git-crypt
    git-secret
    #unsupported gnome.gnome-keyring
    gnome-online-accounts
    gnupg
    gnuplot
    gnuradio
    gnutar
    gperftools
    gpgme
    #already gpsbabel
    gpsbabel-gui
    #unsupported gpsd
    #unsupported gptfdisk
    unstable.gqrx-portaudio
    graphicsmagick_q16
    graphviz
    #grig
    gspell
    gtk-vnc
    #why gtk3
    #why gtkmm
    #why gtkmm3
    units
    gv
    gvfs
    hamlib_4
    #hesiod
    #why hidapi
    htmlq
    htop
    id3lib
    #id3tool
    iftop
    imagemagickBig
    #why imake
    inetutils
    unstable.inkscape
    #inkscape-app
    iperf3
    ipmitool
    irssi
    #why isl
    jc
    #why jemalloc
    jp
    #why jpeg
    #already jq
    #why jsoncpp
    #unsupported julia
    #buildfail kicad
    #ld64
    #unsupported ldapvi
    less
    #lft
    libcanberra
    libde265
    libftdi1
    geoip
    gsm
    libidn2
    libjpeg
    libpsl
    libraw
    libupnp
    libzip
    #already from soapysdr-with-plugins limesuite
    #unsupported lirc
    #why llvm-9.0
    #why llvm-14
    lua
    lzip
    lzma
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
    #macutil
    #makeicns
    libicns
    unstable.mariadb_1011.client
    mdbtools
    mediainfo
    mercurial
    metasploit
    #unsupported mikmod
    minicom
    miniupnpc
    #mlir-14
    mono
    moreutils
    mosh
    mosquitto
    most
    #mpeg2vidcodec
    #mpgtx
    #why mpir
    mpv
    mtr
    multimon-ng
    nbd
    ncdu
    ncftp
    #why nghttp2
    nmap
    nodejs # 18
    #nodejs15
    #nodejs17
    #why npm6
    #why npm7
    nodePackages.npm
    #ntpsec
    #nvm
    fnm
    #unsupported nx-libs
    oath-toolkit
    octaveFull
    #unsupported openafs
    #openafs-signed-kext
    #why OpenBLAS
    openconnect
    opencv
    openntpd
    openocd
    openssh
    openssl
    #collision openssl_1_1
    openvpn
    #osxfuse
    #p5-devel-repl
    file-rename
    #already exiftool
    #why p5-soap-lite
    #why p5-term-readline
    #why p5-term-readline-gnu
    #why p5-xml-parser
    #why p5.26-data-dump
    #why p5.26-json
    #why p5.26-time-local
    #why p5.26-utf8-all
    #why p5.28-authen-sasl
    #why p5.28-cgi
    #why p5.28-clone
    #why p5.28-compress-raw-bzip2
    #why p5.28-compress-raw-zlib
    #why p5.28-digest-hmac
    #why p5.28-digest-sha1
    #why p5.28-error
    #why p5.28-file-rename
    #why p5.28-file-slurper
    #why p5.28-gssapi
    #why p5.28-image-exiftool
    #why p5.28-io
    #why p5.28-io-compress
    #why p5.28-io-compress-brotli
    brotli
    #why p5.28-io-socket-inet6
    #why p5.28-net-smtp-ssl
    #why p5.28-socket6
    #why p5.28-term-readkey
    #why p5.28-term-readline-gnu
    perl536Packages.TermReadLineGnu
    #why p5.28-time-hires
    #why p5.28-time-local
    p7zip
    pandoc
    #broken haskellPackages.pandoc-citeproc
    pass
    passExtensions.pass-import
    passExtensions.pass-otp
    passExtensions.pass-update
    passExtensions.pass-genphrase
    passExtensions.pass-checkup
    pass-git-helper
    #unsupported pavucontrol
    pdf2svg
    pdftk
    perl
    pidgin
    pigz
    pipenv
    pixz
    poly2tri-c
    poppler
    #why portmidi
    postgresql
    #unsupported pothos
    pssh
    pstoedit
    pstree
    pulseaudio
    pv
    qemu
    #unsupported qgis
    #why qt5
    #why qwt-qt5
    #why qwt60
    #why qwt61
    radare2
    rapidjson
    rav1e
    rawtherapee
    rcs
    #remctl
    renameutils
    ripgrep
    rizin
    #rlpr
    rlwrap
    #unsupported rpm
    rtl-sdr
    rtl_433
    rubber
    ruby
    rustc
    #rx_tools
    #already screen
    #screenresolution
    #unsupported sdrangel
    simg2img
    sl
    sloccount
    #already smartmontools
    soapyhackrf
    #already socat
    sops
    sourceHighlight
    sox
    spice-gtk
    squashfsTools
    #already sshfs
    #subversion-perlbindings-5.28
    #already telegraf
    terminal-notifier
    #already texinfo
    texlive.combined.scheme-full
    tigervnc
    #insecure tightvnc
    tintin
    tmate
    tmux
    #unsupported traceroute
    transmission
    #already tree
    tsduck
    #tuntaposx
    #unsupported turbovnc
    libuchardet
    unrar
    unrtf
    upx
    #unsupported usbutils
    #broken vapoursynth
    vbindiff
    #unsupported realvnc-vnc-viewer
    vttest
    #already watch
    #broken webkitgtk
    websocat
    #already wget
    #unsupported winetricks
    wireshark
    termshark
    #insecure wkhtmltopdf
    wordnet
    wxSVG
    #x86_64-w64-mingw32-binutils
    xastir
    xdelta
    xmlstarlet
    #xorg-server
    #insecure xpdf
    xqilla
    #unsupported xsane
    yarn
    youtube-dl
    yq
    zbar
    zenith
    #unsupported gnome.zenity
    #zephyr
    #why zimg
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
    bash-prompt-prefix = "(nix:$name)\\040";
  };
  system.stateVersion = 4;

  users.users.quentin = {
    description = "Quentin Smith";
    uid = 501;
    home = "/Users/quentin";
    shell = "/run/current-system/sw/bin/bash";
  };

  home-manager.users.quentin = {
    home.stateVersion = "22.11";

    imports = [
      ../nix/home/base.nix
    ];

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
        font.normal.family = "Monaco";
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
