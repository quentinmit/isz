{ lib, pkgs, config, ... }:
{
  imports = [
    ./sshd.nix
  ];
  config = {
    time.timeZone = "America/New_York";
    i18n.defaultLocale = "en_US.UTF-8";

    nixpkgs.overlays = [
      (import ./pkgs/all-packages.nix)
    ];
    nixpkgs.config.allowUnfree = true;
    hardware.enableAllFirmware = true;

    nix.settings = {
      extra-experimental-features = [ "nix-command" "flakes" ];
    };

    networking.domain = "isz.wtf";

    environment.systemPackages = with pkgs; [
      acpica-tools
      # apt-file # Debian
      # bash-completion # programs.bash.enableCompletion
      file
      bintools # FIXME: Needed for lesspipe?
      util-linux # already present
      host # already present
      dig
      bwm_ng
      # command-not-found # programs.command-not-found.enable
      cpuset
      curlFull
      # debsums # Debian
      drm_info
      vim
      ((emacsPackagesFor emacs-nox).emacsWithPackages (epkgs: [
        epkgs.nix-mode
        epkgs.magit
      ]))
      exfatprogs
      fping
      glances
      gawk # already present
      htop
      # texinfoInteractive # already present
      input-utils
      # ionit # Uhh
      iotop
      jq
      lsof
      # man # already present
      # mlocate # services.locate.enable
      # mtr # programs.mtr.enable
      ncdu
      netcat-openbsd
      nmap
      # rfkill
      rsync
      screen
      socat
      sqlite
      strace
      sysstat
      inetutils # provides telnet
      tree
      tshark
      usbutils
      v4l-utils
      wget
      # System daemons/parts
      bridge-utils
      # certbot
      # docker-compose
      # docker # virtualization.docker.enable
      # fbset # Not found?
      ffmpeg-headless
      go
      i2c-tools
      iptables
      # linux-cpupower # Not found?
      lm_sensors
      # net-tools # Already present
      nvme-cli
      # podman
      # python311 # pyvenv is part of python311
      # smartmontools # services.smartd.enable
      net-snmp
      # snmp-mibs-downloader # Not found?
      vlan
      # wireless-regdb
      # wirelesstools
    ];
    services.locate.enable = true;
    services.locate.locate = pkgs.mlocate;
    services.locate.localuser = null;
    programs.mtr.enable = true;
    programs.wireshark.enable = true;
    services.smartd.enable = true;
    # Enable the OpenSSH daemon.
    services.openssh.enable = true;
    # TODO: set HISTSIZE to 100000
    programs.git.enable = true;

    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.users.root = {
      home.stateVersion = "22.11";
      programs.home-manager.enable = true;
      # ~/.gitconfig and ~/.config/git/ignore
      programs.git = {
        enable = true;
        ignores = [
          "*~"
        ];
        userName = "Quentin Smith";
        userEmail = "quentin@mit.edu";
        aliases = {
          up = "pull --rebase";
          k = "log --graph --abbrev-commit --pretty=oneline --decorate";
        };
      };
    };
    # TODO: Configure emacs:
    #  - Enable MELPA
    #  - gofmt-command = goimports
    #  - ido-mode = both
    #  - packages-selected-packages = dockerfile-mode go-mode yaml-mode
    #  - go-mode-setup before-save-hook gofmt-before-save
    #  - go-mode-hook go-mode-setup
  };
}
