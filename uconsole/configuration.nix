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

  hardware.keyboard.qmk.enable = true;

  networking.hostName = "uconsole";

  networking.networkmanager.enable = true;

  # https://github.com/raspberrypi/linux/issues/6049#issuecomment-2485431104
  boot.extraModprobeConfig = ''
    options brcmfmac feature_disable=0x200000
  '';

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
    byobu
  ];

  services.xserver.enable = true;
  # Broken on arm:
  # https://github.com/llvm/llvm-project/pull/78704
#   services.displayManager.ly = {
#     enable = true;
#     settings = {
#       animation = "matrix";
#       bigclock = "en";
#     };
#   };
  services.xserver.displayManager.setupCommands = ''
    ${pkgs.xorg.xrandr}/bin/xrandr --output DSI-1 --rotate right
  '';
  services.displayManager.sddm.enable = true;
  services.xserver.windowManager.twm.enable = true;

  users.users.root = {
    initialHashedPassword = "";
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
      "podman"
      "audio"
    ];
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

