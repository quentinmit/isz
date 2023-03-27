{ config, pkgs, lib, ... }:

{
  imports = [
    ../nix/base.nix
    ../nix/networkd.nix
  ];

  nixpkgs.overlays = [
    (final: super: {
      makeModulesClosure = x:
        super.makeModulesClosure (x // { allowMissing = true; });
    })
  ];

  sops.defaultSopsFile = ./secrets.yaml;
  
  boot = {
    kernelPackages = pkgs.linuxPackages_rpi4;
    tmpOnTmpfs = true;
    initrd.availableKernelModules = [ "usbhid" "usb_storage" ];
    # ttyAMA0 is the serial console broken out to the GPIO
    kernelParams = [
      "8250.nr_uarts=1"
      "console=ttyAMA0,115200"
      "console=tty1"
    ];

    loader.raspberryPi = {
      enable = true;
      version = 4;
    };
    loader.grub.enable = false;
  };

  networking.hostName = "bedroom-pi";

  isz.networking = {
    lastOctet = 33;
    macAddress = "dc:a6:32:98:38:a8";
  };

  nix = {
    autoOptimiseStore = true;
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
    # Free up to 1GiB whenever there is less than 100MiB left.
    extraOptions = ''
      min-free = ${toString (100 * 1024 * 1024)}
      max-free = ${toString (1024 * 1024 * 1024)}
    '';
  };
  system.stateVersion = "22.11";
}
  
