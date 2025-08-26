{ config, pkgs, lib, oom-hardware, ... }:

{
  imports = [
    ../nix/raspi.nix
    oom-hardware.nixosModules.uconsole
    ./aio.nix
    ./quentin.nix
  ];

  sops.defaultSopsFile = ./secrets.yaml;

  boot = {
    tmp.useTmpfs = true;
  };

  console = {
    earlySetup = true;
    font = "ter-v32n";
    packages = with pkgs; [terminus_font];
  };

  rpi.serialConsole = false;

  boot.loader.isz-raspi.uboot.rpi4 = pkgs.ubootRaspberryPi4_64bit.override {
    extraConfig = ''
      CONFIG_DISPLAY_BOARDINFO_LATE=y
      CONFIG_BOOTDELAY=-2
    '';
    extraPatches = [
      ./uboot-disable-serial.patch
    ];
  };

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

  hardware.bluetooth.enable = true;

  hardware.deviceTree.overlays = let
    mAh = 2*2600;
    uWh = 3700 * mAh;
    uAh = 1000 * mAh;
  in [{
    name = "99-isz";
    filter = "bcm2711-rpi-cm4.dtb";
    dtsText = ''
      /dts-v1/;
      /plugin/;

      /{
        compatible = "brcm,bcm2711";
        fragment@1 {
          target-path = "/battery@0";
          __overlay__ {
            voltage-min-design-microvolt = <3000000>;
            energy-full-design-microwatt-hours = <${toString uWh}>;
            charge-full-design-microamp-hours = <${toString uAh}>;
          };
        };
      };
    '';
  }];

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
  # Treat the ball as a trackpoint to get better acceleration.
  services.udev.extraHwdb = ''
    id-input:modalias:input:b0003vFEEDp0000e0111-e0,1,2,4,k110,111,112,113,114,115,116,117,r0,1,6,8,B,C,am4,lsfw
     ID_INPUT_POINTINGSTICK=1
  '';
  environment.etc."libinput/local-overrides.quirks".text = ''
    [uConsole Keyboard Mouse]
    MatchName=Clockwork uConsole*
    MatchUdevType=pointingstick
    AttrTrackpointMultiplier=5.0
  '';

  networking.hostName = "uconsole";

  networking.networkmanager.enable = true;

  services.firewalld = {
    enable = true;
    package = pkgs.firewalld-gui;
    config = {
      DefaultZone = "public";
      FirewallBackend = "nftables";
    };
  };

  # https://github.com/raspberrypi/linux/issues/6049#issuecomment-2485431104
  boot.extraModprobeConfig = ''
    options brcmfmac feature_disable=0x200000
  '';

  networking.firewall.enable = false;

  isz.openssh = {
    hostKeyTypes = ["ecdsa" "ed25519" "rsa"];
    useSops = true;
  };

  isz.telegraf = {
    enable = true;
    smart.enable = false;
    powerSupply = true;
  };

  isz.vector = {
    enable = true;
  };

  environment.systemPackages = with pkgs; [
    mmc-utils
    iw
    byobu
    qmk
    dtc
    ubootEnvtools
    kdePackages.plasma-firewall
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
  services.desktopManager.plasma6.enable = true;
  programs.kdeconnect.enable = true;

  nixpkgs.overlays = [
    (final: prev: {
      retroarch-joypad-autoconfig = prev.retroarch-joypad-autoconfig.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          cp -vR ${./retroarch-joypad-autoconfig}/* ./
        '';
      });
    })
  ];

  users.users.root = {
    initialHashedPassword = "";
  };

  users.groups.gpio = {};
  users.users.quentin = {
    isNormalUser = true;
    description = "Quentin Smith";
    extraGroups = [
      "dialout"
      "plugdev"
      "networkmanager"
      "video"
      "wheel"
      "wireshark"
      "libvirtd"
      "podman"
      "audio"
      "gpio"
    ];
    openssh.authorizedKeys.keys = config.users.users.root.openssh.authorizedKeys.keys;
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

