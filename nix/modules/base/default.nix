{ lib, pkgs, config, nix-index-database, home-manager, sops-nix, ... }:
let
  isNixDarwin = lib ? nixos;
  isNixOS = !isNixDarwin;
in {
  imports = [
  ];
  config = {
    time.timeZone = "America/New_York";

    nixpkgs.overlays = [
      (import ../../pkgs/all-packages.nix)
    ];
    nixpkgs.config.allowUnfree = true;

    nix.settings = {
      extra-experimental-features = [ "nix-command" "flakes" ];
    };

    environment.systemPackages = with pkgs; [
      w3m-nographics
      testdisk
      ddrescue
      ccrypt

      sshfs-fuse
      socat
      tcpdump

      pciutils

      unzip
      zip

      acpica-tools
      # apt-file # Debian
      # bash-completion # programs.bash.enableCompletion
      file
      bintools # FIXME: Needed for lesspipe?
      host # already present
      dig
      bwm_ng
      # command-not-found # programs.command-not-found.enable
      curlFull
      # debsums # Debian
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
      fping
      glances
      gawk # already present
      htop
      # texinfoInteractive # already present
      # ionit # Uhh
      jq
      lsof
      # man # already present
      # mlocate # services.locate.enable
      # mtr # programs.mtr.enable
      ncdu
      nix-tree
      nmap
      # rfkill
      rsync
      screen
      socat
      sqlite-interactive
      inetutils # provides telnet
      tree
      tshark
      wget
      # System daemons/parts
      # certbot
      # docker-compose
      # docker # virtualization.docker.enable
      # fbset # Not found?
      ffmpeg-headless
      go
      # linux-cpupower # Not found?
      # podman
      # python311 # pyvenv is part of python311
      smartmontools
      # snmp-mibs-downloader # Not found?
      # wireless-regdb
      # wirelesstools
    ];
  };
}
