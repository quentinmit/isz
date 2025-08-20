{ pkgs,
graphical ? false,
... }:
let
  packages = with pkgs; [
    # Filesystem
    sshfs-fuse
    squashfsTools

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
    (lib.lowPrio pstree) # low priority to prefer pstree from psmisc on Linux

    # Networking
    (if graphical then w3m else w3m-nographics)
    socat
    tcpdump
    bwm_ng
    curlFull
    host # already present
    dig
    fping
    mosh
    mosh-server-upnp
    # mtr # programs.mtr.enable
    net-snmp
    nmap
    openssl
    socat
    telnet
    wget

    # Compression
    unzip
    zip
    ccrypt
    unar

    # Development
    #bintools # FIXME: Needed for lesspipe?
    #binutils # FIXME: Propagates glibc
    go
    sqlite-interactive

    # Nix
    nix-diff
    nix-tree
    nix-output-monitor
    nvd

    # Shell utilities
    # bash-completion # programs.bash.enableCompletion
    dyff
    file
    file-rename
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
    # Nix
    nix-du

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
    alsa-utils
    drm_info
    usbutils
    input-utils
    v4l-utils
    lm_sensors
    i2c-tools
    libinput
    evtest

    # Performance tools
    iotop
    psmisc
    strace
    sysstat
    cpuset
    s-tui

    # Networking
    bridge-utils
    iptables
    nftables
    vlan
    netcat-openbsd
    ethtool

    # Utilities
    util-linux
  ];
in
packages
