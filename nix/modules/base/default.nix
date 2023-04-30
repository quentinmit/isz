{ lib, pkgs, config, nix-index-database, home-manager, sops-nix, ... }:
let
  isNixDarwin = lib ? nixos;
  isNixOS = !isNixDarwin;
in {
  imports = [
  ] ++ (if isNixDarwin then [
    home-manager.darwinModules.home-manager
  ] else [
    home-manager.nixosModules.home-manager
  ]);
  options = with lib; {
    isz.programs = {
      tshark = mkOption {
        type = types.bool;
        default = true;
      };
    };
  };
  config = let
    prg = config.isz.programs;
  in {
    time.timeZone = "America/New_York";

    nixpkgs.overlays = [
      (import ../../pkgs/all-packages.nix)
    ];
    nixpkgs.config.allowUnfree = true;

    nix.settings = {
      extra-experimental-features = [ "nix-command" "flakes" ];
      # Nix on macOS has a race condition when this is turned on.
      # https://github.com/NixOS/nix/issues/7273
      auto-optimise-store = lib.mkIf (!pkgs.stdenv.isDarwin) true;
    };

    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;

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
      net-snmp
      nix-tree
      nmap
      # rfkill
      rsync
      screen
      socat
      sqlite-interactive
      inetutils # provides telnet
      tree
      watch
      wget
      # System daemons/parts
      # certbot
      # docker-compose
      # docker # virtualization.docker.enable
      # fbset # Not found?
      #ffmpeg-headless
      go
      # linux-cpupower # Not found?
      # podman
      # python311 # pyvenv is part of python311
      smartmontools
      # wireless-regdb
      # wirelesstools
    ]
    ++ lib.lists.optional prg.tshark pkgs.tshark;

    environment.etc."snmp/snmp.conf".text = ''
      mibdirs +${pkgs.snmp-mibs}/share/snmp/mibs
    '';
  };
}
