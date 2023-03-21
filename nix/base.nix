{ lib, pkgs, config, ... }:
{
  config = {
    time.timeZone = "America/New_York";
    i18n.defaultLocale = "en_US.UTF-8";

    nixpkgs.overlays = [
      (import ./pkgs/all-packages.nix)
    ];
    nixpkgs.config.allowUnfree = true;
    hardware.enableAllFirmware = true;

    networking.domain = "isz.wtf";

    users.users."root".openssh.authorizedKeys.keys = [
      "ssh-dss AAAAB3NzaC1kc3MAAACBAKkmA85sGJjOMkH0lYj1apiCyvyBtKYJcM3sBn4lBrDV59E1FzgE2SvNnysgHVjVJtrqzt9AbYShDggAOgH3uSoc8wppETurUeTTiS59Y0WzWIHNTEAcsKvQw+2Zj3pU0vYU01cUhm2iV9Cw49gf7VwRtCoavVzsQaHMDWq4vMbpAAAAFQCtpPp74y1vTh14Z8I4/bO1/kWCNwAAAIBGCm5M6envG4iojPor4gXAIsZdlHVK/RNSl6jmisuMnx8a/e8H45LCBmEDYY7px8sSgSt85x6p6qd2UsPI1vHxd945PTKjbpiRNoCifKEBdKLVueYo2jlBIgKRYKJ4oMvyxFGuzaaMokO2AVlmeFjnQF4qIV6G2PhRIJ6+l+j3qAAAAIEAi5F+CBVmOvwazgI9aDmNXr+29Y6L7QW4EmA0pFiQG/aPhI37SeaArf7+/v2XSZMzqNa2VNiu8pDCUngU5YdZLb5DoHTSx4W5j3hgT5ken4WYd8SxxA5A/PEzLbZcEBiml5EN3EA/yymtyv34CzV5waOvyg80khraulngix5r2sY= quentins@209.177.24.26.dhcp.lightlink.com"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCUtRBFYPQ0OicLdAVNJih4JZp0JsGnKM/jRnG4GzGGW/bvNYtcNRCNWKHkMKAZvHSxLw8H3UVDDpyYWPnCw75rSR9aAIOVMAa4ScQyBKPvPNEM55XQT+AW8oapeSDkVrvhxJpLf8vCBz0jx15meQgQm9T/CnmHnigojcGbxtwe8znL2VQoZZnrd9KW69a94CEQuJZAKIur0Y00NoMuZYhgRFQMmuxXlqlwJSohTPHziHUxLpp/oqHnwh6er7bZwHfw7pBwSrwOyd4z4P1uWwJf2G0ShpVR07HtTtHLWIR+08ms0MiRpkgdPNFc4M9vlG4ZwOUVEuyJbJIj9VZIssLehKXXvOFj6nFqGTgMfflxd5vuS4bPJd2wRJymi+LXFMZcrg/8q8+6FJqUlp46hC3gR8iYQpLHQ4vpZgjNXncm5hAJsKDzQMrpHHkjR4jMibqsSMTHFNdXgzu4lZ2U/bxz33dEA/hOWmoWKK+zh6fjtRdMgT2ygnbVCrDtRW8zlmD4g88c1a02slOnK4tnM8XQ8xHP+n6cGfrwM1vCpNtxGWTrt+DvfTLhJhB74VTNYc4cLAQQf1d+k+wjjreswMCmLC8scmoyRqkhvEqatoRqQaeo9DG8OTUSZnmezZX4r5cF+fOsKbFRzAwKDBQqeA8oW6egTVNNxpQDOBUrrlopCw== quentin@GREEN-SEVEN-FIFTY.MIT.EDU"
      "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAsGMP08Nq2dliWfi3WnODNuaOrRUNuRegwC81atTgeNSndkYsgCXEPthiDrjRd2vpM06R4sMLAPUmvXQyEr8QqR+TUwrJq2eghhBycNXChXdPd9ahaSMsWReoyyRqc32OPidF6p/t9Rd+SAAAF6a+skcoV8Nu1HgGwMNe7ByuOub6HGTdvTo13PTuAlugcEhDfakaMkxZ41kXQbT5xPOWhKQY2vfZaC35gd86rPqM9Ols+4wEaByFXijsbWmEOr4wJmOfe4hWnO9sQFsC9oOrFBRd/XipQnMg522cepIY7nVMPi5UDYEe8O5dgs+7GrIKxWcwzdglBgE0nYp8xp6BDw== quentin@quentin-macbookpro.cam.corp.google.com"
    ]

    environment.systemPackages = with pkgs; [
      acpica-tools
      # apt-file # Debian
      # bash-completion # programs.bash.enableCompletion
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
      emacs-nox
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
    services.smartd.enable = true;
    # Enable the OpenSSH daemon.
    services.openssh.enable = true;
    # TODO: set HISTSIZE to 100000
    programs.git.enable = true;
    # TODO: Set ~/.config/git/ignore to *~
    # TODO: Configure emacs:
    #  - Enable MELPA
    #  - gofmt-command = goimports
    #  - ido-mode = both
    #  - packages-selected-packages = dockerfile-mode go-mode yaml-mode
    #  - go-mode-setup before-save-hook gofmt-before-save
    #  - go-mode-hook go-mode-setup
    # TODO: ~/.gitconfig
    #  - user.name = "Quentin Smith"
    #  - user.email = "quentin@mit.edu"
    #  - alias.up = "pull --rebase"
    #  - alias.k = "log --graph --abbrev-commit --pretty=oneline --decorate"
  };
}
