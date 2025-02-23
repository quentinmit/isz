{ config, pkgs, lib, nixpkgs, ... }:

{
  imports = [
    ../nix/raspi.nix
    ./pnio2mqtt.nix
  ];

  sops.defaultSopsFile = ./secrets.yaml;

  boot = {
    tmp.useTmpfs = true;
    # Disable USB in uboot to work around a bug.
    loader.isz-raspi = {
      uboot.rpi4 = pkgs.ubootRaspberryPi4_64bit_nousb;
      forceHDMI = true;
    };
  };

  hardware.deviceTree.overlays = [{
    name = "w1-gpio-overlay";
    dtsText = ''
      // Definitions for w1-gpio module (without external pullup)
      /dts-v1/;
      /plugin/;

      / {
        compatible = "brcm,bcm2711";

        fragment@0 {
          target-path = "/";
          __overlay__ {
            w1: onewire@0 {
              compatible = "w1-gpio";
              pinctrl-names = "default";
              pinctrl-0 = <&w1_pins>;
              gpios = <&gpio 17 0>;
              status = "okay";
              reg = <17>;
            };
          };
        };

        fragment@1 {
          target = <&gpio>;
          __overlay__ {
            w1_pins: w1_pins@0 {
              brcm,pins = <17>;
              brcm,function = <0>; // in (initially)
              brcm,pull = <0>; // off
              reg = <17>;
            };
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

  networking.hostName = "bedroom-pi";

  isz.networking = {
    lastOctet = 33;
    macAddress = "dc:a6:32:98:38:a8";
    linkzone = true;
    profinet = true;
  };
  networking.firewall.enable = false;

  isz.openssh = {
    hostKeyTypes = ["ecdsa" "ed25519" "rsa"];
    useSops = true;
  };

  isz.telegraf = {
    enable = true;
    smart.enable = false;
    w1 = true;
    interval.sensors = "30s";
  };

  isz.vector = {
    enable = true;
  };

  environment.systemPackages = with pkgs; [
    mmc-utils
    iw
    wpa_supplicant
  ];

  users.users.root = {
    hashedPassword = "";
  };

  services.udev.rules = [
    {
      SUBSYSTEM = "tty";
      "ATTRS{idProduct}" = "2008";
      "ATTRS{idVendor}" = "0557";
      RUN = { op = "+="; value = "${pkgs.coreutils}/bin/ln -f $devnode /dev/ttyWago"; };
      OWNER = { op = "="; value = "wago-logger"; };
      GROUP = { op = "="; value = "wago-logger"; };
    }
  ];
  sops.secrets.wago_logger_influx_token = {
    owner = "wago-logger";
  };
  systemd.services.wago-logger = {
    description = "Wago Logger";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    environment = {
      INFLUX_SERVER = "http://influx.isz.wtf:8086/";
    };
    serviceConfig = {
      User = "wago-logger";
      Group = "wago-logger";
      Restart = "always";
      RestartSec = "5s";
    };
    unitConfig = {
      StartLimitIntervalSec = "0";
    };
    script = ''
      export INFLUX_TOKEN="$(cat ${lib.strings.escapeShellArg config.sops.secrets.wago_logger_influx_token.path})"
      exec ${pkgs.callPackage ./go {}}/bin/wago-logger -d /dev/ttyWago
    '';
  };
  users.extraUsers.wago-logger = {
    isSystemUser = true;
    group = "wago-logger";
  };
  users.extraGroups.wago-logger = {};

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
  system.stateVersion = "22.11";
}

