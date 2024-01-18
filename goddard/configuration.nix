{ config, pkgs, lib, nixpkgs, disko, nixos-hardware, ... }:

{
  imports = [
    #./hardware-configuration.nix
    nixos-hardware.nixosModules.framework-13-7040-amd # TODO: Switch to 16 when it exists
    ./disko.nix
    disko.nixosModules.disko
  ];
  nixpkgs.hostPlatform = "x86_64-linux";

  system.stateVersion = "23.11";

  sops.defaultSopsFile = ./secrets.yaml;

  networking.hostName = "goddard";

  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot = {
    enable = true;
    memtest86.enable = true;
  };

  environment.etc."lvm/lvm.conf".text = ''
    devices/issue_discards=1
  '';
  services.fstrim.enable = true;
  services.smartd.enable = true;

  services.fwupd.enable = true;

  hardware.bluetooth.enable = true;

  networking.networkmanager.enable = true;

  services.opensnitch = {
    enable = true;
  };

  security.polkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    jack.enable = true;
    pulse.enable = true;
  };

  services.xserver.enable = true;
  services.xserver.displayManager.sddm.enable = true;
  services.xserver.windowManager.twm.enable = true;
  services.xserver.desktopManager.plasma5.enable = true;

  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  programs.dconf.enable = true;

  krb5.enable = true;
  krb5.libdefaults.default_realm = "ATHENA.MIT.EDU";
  krb5.realms = {
    "ATHENA.MIT.EDU" = {
      admin_server = "kerberos.mit.edu";
      default_domain = "mit.edu";
      kdc = [
        "kerberos.mit.edu:88"
        "kerberos-1.mit.edu:88"
        "kerberos-2.mit.edu:88"
      ];
    };
    "ZONE.MIT.EDU" = {
      admin_server = "casio.mit.edu";
      kdc = [
        "casio.mit.edu"
        "seiko.mit.edu"
      ];
    };
  };
  krb5.domain_realm = {
    "exchange.mit.edu" = "EXCHANGE.MIT.EDU";
    "mit.edu" = "ATHENA.MIT.EDU";
    "win.mit.edu" = "WIN.MIT.EDU";
    "csail.mit.edu" = "CSAIL.MIT.EDU";
    "media.mit.edu" = "MEDIA-LAB.MIT.EDU";
    "whoi.edu" = "ATHENA.MIT.EDU";
  };

  users.users.quentin = {
    isNormalUser = true;
    description = "Quentin Smith";
    extraGroups = [
      "dialout"
      "networkmanager"
      "video"
      "wheel"
    ];
  };

  home-manager.users.quentin = {
    home.stateVersion = "23.11";

    isz.quentin = true;
    isz.graphical = true;
    isz.plasma.enable = true;

    programs.atuin.settings.sync_address = "https://atuin.isz.wtf";
  };
}
