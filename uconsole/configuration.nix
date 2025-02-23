{ config, pkgs, lib, oom-hardware, ... }:

{
  imports = [
    ../nix/raspi.nix
    oom-hardware.nixosModules.uconsole
  ];

  boot = {
    tmp.useTmpfs = true;
  };

  console = {
    earlySetup = true;
    font = "ter-v32n";
    packages = with pkgs; [terminus_font];
  };

  rpi.serialConsole = false;

  boot.loader.isz-raspi.config = {
    gpio = [
      "10=ip,np"
      "11=op"
    ];
    arm_boost = true;

    #over_voltage = 6;
    #arm_freq = 2000;
    #gpu_freq = 750;

    display_auto_detect = true;
    ignore_lcd = true;
    disable_overscan = true;
    disable_fw_kms_setup = true;
    disable_audio_dither = true;
    pwm_sample_bits = 20;
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

  networking.hostName = "uconsole";

  networking.networkmanager.enable = true;

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
  system.stateVersion = "25.05";
}

