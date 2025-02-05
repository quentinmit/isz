{ config, pkgs, lib, ... }:

{
  imports = [
    ../nix/raspi.nix
  ];

  boot = {
    tmp.useTmpfs = true;
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

  networking.hostName = "rascsi";

  isz.networking = {
    lastOctet = 35;
    macAddress = "dc:a6:32:75:54:dc";
  };
  networking.firewall.enable = false;

  isz.openssh = {
    hostKeyTypes = ["ecdsa" "ed25519" "rsa"];
  };

  isz.telegraf = {
    enable = false; # TODO: Enable
    smart.enable = false;
  };

  environment.systemPackages = with pkgs; [
    mmc-utils
    iw
    wpa_supplicant
  ];

  users.users.root = {
    hashedPassword = "";
  };

  services.piscsi = {
    enable = true;
  };

  nix = {
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
  system.stateVersion = "24.11";
}

