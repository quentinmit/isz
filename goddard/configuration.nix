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

  programs.dconf.enable = true;

  users.users.quentin = {
    isNormalUser = true;
    description = "Quentin Smith";
    extraGroups = [
      "wheel"
      "networkmanager"
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
