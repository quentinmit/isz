{ config, pkgs, lib, nixpkgs, disko, nixos-hardware, lanzaboote, ... }:
{
  imports = [
    nixos-hardware.nixosModules.common-cpu-amd
    nixos-hardware.nixosModules.common-cpu-amd-pstate
    nixos-hardware.nixosModules.common-cpu-amd-zenpower
    nixos-hardware.nixosModules.common-cpu-amd-raphael-igpu
    nixos-hardware.nixosModules.common-gpu-amd
    ./disko.nix
    ./quentin.nix
    disko.nixosModules.disko
  ];
  nixpkgs.hostPlatform = "x86_64-linux";

  system.stateVersion = "24.05";

  sops.defaultSopsFile = ./secrets.yaml;

  networking.hostName = "heartofgold";
  networking.hostId = "8daa50bc";

  boot.initrd.systemd.enable = true;
  boot.zfs.requestEncryptionCredentials = ["zpool"];
  boot.kernelModules = [
    "nct6775" # For sensors
  ];
  # FIXME isz.secureBoot.enable = true;
  boot.loader.grub.enable = false;
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.memtest86.enable = true;

  isz.openssh = {
    hostKeyTypes = ["ecdsa" "ed25519" "rsa"];
    useSops = true;
  };

  isz.networking = {
    lastOctet = 106; # FIXME 101
    macAddress = "E8:9C:25:6B:1E:B9";
    vlan88 = true;
  };

  networking.firewall.enable = false;

  services.smartd.enable = true;

  services.fwupd.enable = true;

  hardware.bluetooth.enable = true;

  isz.telegraf = {
    enable = true;
    intelRapl = true;
    amdgpu = true;
    powerSupply = true;
    drm = true;
    zfs = true;
  };

  security.polkit.enable = true;

  isz.pipewire.enable = true;

  isz.gpu.enable = true;
  isz.gpu.amd = true;

  environment.systemPackages = with pkgs; [

  ];

  services.xserver.enable = true;
  services.xserver.displayManager.gdm = {
    enable = true;
    autoSuspend = false;
  };
  services.xserver.desktopManager.gnome.enable = true;
  services.xserver.windowManager.twm.enable = true;

  fonts.fontDir.enable = true;

  programs.chromium = {
    enable = true;
  };

  programs.steam.enable = true;

  programs.wireshark.package = pkgs.wireshark;

  # TODO: Switch to systemd-resolved for mDNS
  services.avahi = {
    enable = true;
    nssmdns4 = true;
  };

  isz.krb5.enable = true;

  nix.settings = {
    trusted-users = [ "root" "quentin" ];
  };

  users.users.quentin = {
    isNormalUser = true;
    description = "Quentin Smith";
    extraGroups = [
      "dialout"
      "networkmanager"
      "video"
      "wheel"
      "wireshark"
      "libvirtd"
      "audio"
    ];
    openssh.authorizedKeys.keys = config.users.users.root.openssh.authorizedKeys.keys;
  };
}
