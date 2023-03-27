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

    # Loader is configured by sd-image-aarch64.nix
    #loader.raspberryPi = {
    #  enable = true;
    #  version = 4;
    #};
    loader.grub.enable = false;
    #loader.generic-extlinux-compatible.enable = lib.mkForce false;
  };

  # Skip building HTML manual, but still install other docs.
  documentation.doc.enable = false;
  environment.pathsToLink = [ "/share/doc" ];
  environment.extraOutputsToInstall = [ "doc" ];

  # Use x86-64 qemu for run-vm
  virtualisation.vmVariant = {
    virtualisation.qemu.package = pkgs.pkgsNativeGnu64.qemu;
    virtualisation.graphics = false;
  };

  networking.hostName = "bedroom-pi";

  isz.networking = {
    lastOctet = 33;
    macAddress = "dc:a6:32:98:38:a8";
  };

  isz.openssh = {
    hostKeyTypes = ["ecdsa" "ed25519" "rsa"];
    useSops = true;
  };

  nix = {
    settings.auto-optimise-store = true;
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
  
