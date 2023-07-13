{ pkgs, ... }:
let
  packages = with pkgs; [
    # Filesystem
    sshfs-fuse

    # Block devices
    testdisk
    ddrescue
    smartmontools

    # Other devices
    acpica-tools
    pciutils

    # Performance tools
    glances
    htop
    lsof

    # Networking
    w3m-nographics
    socat
    tcpdump
    bwm_ng
    curlFull
    host # already present
    dig
    fping
    # mtr # programs.mtr.enable
    net-snmp
    nmap
    openssl
    socat
    inetutils # provides telnet
    wget

    # Compression
    unzip
    zip
    ccrypt

    # Development
    bintools # FIXME: Needed for lesspipe?
    go
    sqlite-interactive

    # Editors
    (pkgs.vim.customize {
      name = "vim";
      vimrcConfig.packages.default = {
        start = [ pkgs.vimPlugins.vim-nix ];
      };
      vimrcConfig.customRC = "syntax on";
    })
    (
      if pkgs.stdenv.buildPlatform.config != pkgs.stdenv.hostPlatform.config then
        emacs-nox
      else
        ((emacsPackagesFor emacs-nox).emacsWithPackages (epkgs: [
          epkgs.nix-mode
          epkgs.magit
          epkgs.go-mode
          epkgs.yaml-mode
        ]))
    )

    # Nix
    nix-diff
    nix-tree
    nix-output-monitor
    nvd

    # Shell utilities
    # bash-completion # programs.bash.enableCompletion
    dyff
    file
    gawk # already present
    gnused
    jq
    # man # already present
    ncdu
    screen
    # texinfoInteractive # already present
    tree
    watch

    # ionit # Uhh
    # mlocate # services.locate.enable
    # rfkill
    rsync
    # System daemons/parts
    # certbot
    # docker-compose
    # docker # virtualization.docker.enable
    # fbset # Not found?
    #ffmpeg-headless
    # linux-cpupower # Not found?
    # podman
    # python311 # pyvenv is part of python311
    # wireless-regdb
    # wirelesstools
  ] ++ lib.optionals pkgs.stdenv.isLinux [
    # Partition/MBR tools
    ms-sys
    efibootmgr
    efivar
    parted
    gptfdisk

    # Filesystems
    exfatprogs
    fuse
    fuse3

    # Block devices
    sdparm
    hdparm
    nvme-cli
    cryptsetup

    # Other devices
    drm_info
    usbutils
    input-utils
    v4l-utils
    lm_sensors
    i2c-tools

    # Performance tools
    iotop
    psmisc
    strace
    sysstat
    cpuset

    # Networking
    bridge-utils
    iptables
    vlan
    netcat-openbsd

    # Utilities
    util-linux
  ];
in
packages
