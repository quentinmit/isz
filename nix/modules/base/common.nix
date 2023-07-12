{ lib, pkgs, config, nix-index-database, home-manager, options, sops-nix, self, ... }:
# This config file is loaded by both nixos and nix-darwin, so only options that
# exist on both can be placed here. See ./default.nix and ../darwin/base.nix for
# OS-specific options.
{
  options = with lib; {
  };
  config = {
    time.timeZone = "America/New_York";

    nixpkgs.config.allowUnfree = true;

    nix.package = lib.mkDefault pkgs.nixVersions.nix_2_16;

    nix.settings = {
      extra-experimental-features = [ "nix-command" "flakes" "repl-flake" ];
      # Nix on macOS has a race condition when this is turned on.
      # https://github.com/NixOS/nix/issues/7273
      auto-optimise-store = lib.mkIf (!pkgs.stdenv.isDarwin) true;
    };

    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.extraSpecialArgs = options._module.specialArgs.value;
    home-manager.sharedModules = builtins.attrValues self.homeModules;

    environment.systemPackages = with pkgs; [
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
    ];

    programs.wireshark.enable = true;

    environment.etc."snmp/snmp.conf".text = ''
      mibdirs +${pkgs.snmp-mibs}/share/snmp/mibs
    '';
  };
}
