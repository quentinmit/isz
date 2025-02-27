# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, nixos-hardware, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./nginx.nix
      ./postfix.nix
      ./postgresql.nix
      ./home-assistant
      ./telegraf.nix
      ./dashboard.nix
      ./grafana
      ./pnio2mqtt.nix
      #./containers.nix
      ./authentik
      ./bluechips.nix
      ./paperless.nix
      ./sdrtrunk
      ./speedtest.nix
      ./loki.nix
      ./vector.nix
      nixos-hardware.nixosModules.common-cpu-amd
      nixos-hardware.nixosModules.common-cpu-amd-pstate
    ];

  sops.defaultSopsFile = ./secrets.yaml;

  # Use the systemd-boot EFI boot loader.
  isz.secureBoot.enable = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  environment.etc."lvm/lvm.conf".text = ''
    devices/issue_discards=1
  '';
  services.fstrim.enable = true;
  services.smartd.enable = true;

  networking.hostName = "workshop"; # Define your hostname.

  isz.openssh = {
    hostKeyTypes = ["ecdsa" "ed25519" "rsa"];
    useSops = true;
  };

  isz.networking = {
    lastOctet = 34;
    macAddress = "04:42:1A:C9:93:8B";
    vlan88 = true;
    linkzone = true;
    profinet = true;
  };

  systemd.services.nscd.environment.NSNCD_WORKER_COUNT = "32";

  hardware.bluetooth.enable = true;

  services.fwupd.enable = true;

  # Select internationalisation properties.
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkbOptions in tty.
  # };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  # users.users.alice = {
  #   isNormalUser = true;
  #   extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
  #   packages = with pkgs; [
  #     firefox
  #     thunderbird
  #   ];
  # };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    sg3_utils
    mqttui
    virtiofsd
    termshark
  ];

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;
  networking.nftables.enable = true;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.11"; # Did you read the comment?

  # Configure udev for Zwave, Fluke45, PWRGate
  services.udev.rules = [
    {
      SUBSYSTEM = "tty";
      "ATTRS{product}" = "Epic-PWRgate";
      RUN = { op = "+="; value = "${pkgs.coreutils}/bin/ln -f $devnode /dev/ttyPwrgate"; };
      OWNER = { op = "="; value = "pwrgate-logger"; };
      GROUP = { op = "="; value = "pwrgate-logger"; };
      "ENV{SYSTEMD_WANTS}" = { op = "+="; value = "pwrgate-logger"; };
     }
    {
      SUBSYSTEM = "tty";
      "ATTRS{idProduct}" = "0200";
      "ATTRS{idVendor}" = "0658";
      RUN = { op = "+="; value = "${pkgs.coreutils}/bin/ln -f $devnode /dev/ttyZwave"; };
      OWNER = { op = "="; value = "zwave-js-ui"; };
      GROUP = { op = "="; value = "zwave-js-ui"; };
    }
    {
      SUBSYSTEM = "tty";
      "ATTRS{idProduct}" = "6011";
      "ATTRS{idVendor}" = "0403";
      "ATTRS{bInterfaceNumber}" = "00";
      RUN = { op = "+="; value = "${pkgs.coreutils}/bin/ln -f $devnode /dev/ttyFluke45"; };
    }
  ];
  # Configure mosquitto
  services.mosquitto = {
    enable = true;
    listeners = [ {
      acl = [
        "topic read $SYS/#"
        "pattern readwrite #"
      ];
      omitPasswordAuth = true;
      settings.allow_anonymous = true;
      # TODO: Restrict to 172.30.96.0/24 and 192.168.88.0/24
      # TODO: Enable SSL/WebSockets
    } ];
  };
  # TODO: Configure tftp
  # Configure postfix
  # Containers?
  # Configure rtl-sdr to hotplug on udev 0bda/2838
  services.rtl-tcp.enable = true;
  # Configure rtlamr
  sops.secrets.rtlamr_influx_token = {
    owner = config.services.rtlamr-collect.user;
  };
  services.rtlamr-collect = {
    enable = true;
    influxdb = {
      tokenPath = config.sops.secrets.rtlamr_influx_token.path;
      url = "http://influx.isz.wtf:8086/";
      org = "44ff94dc2f766f90";
      bucket = "rtlamr";
      measurement = "rtlamr";
    };
    msgtype = "scm,scm+,idm";
    logLevel = "debug";
  };
  systemd.services.rtlamr-collect.serviceConfig.SupplementaryGroups = [ config.users.groups.keys.name ];
  # Configure services.influxdb2
  services.influxdb2 = {
    enable = true;
    settings = {
      reporting-disabled = true;
    };
  };
  # Configure services.grafana
  users.users."${config.services.nginx.user}".extraGroups = [ "grafana" ];
  # Configure pwrgate-logger
  sops.secrets.pwrgate-logger_influx_token = {
    owner = "pwrgate-logger";
    key = "logger_influx_token";
  };
  systemd.services.pwrgate-logger = {
    description = "Pwrgate Logger";
    wants = [ "network-online.target" "influxdb2.service" ];
    after = [ "network-online.target" "influxdb2.service" ];
    environment = {
      INFLUX_SERVER = "http://influx.isz.wtf:8086/";
    };
    unitConfig = {
      StartLimitIntervalSec = "0";
    };
    serviceConfig = {
      User = "pwrgate-logger";
      Group = "pwrgate-logger";
      Restart = "always";
      RestartSec = "5s";
    };
    script = ''
      export INFLUX_TOKEN="$(cat ${lib.strings.escapeShellArg config.sops.secrets.pwrgate-logger_influx_token.path})"
      exec ${pkgs.callPackage ./go {}}/bin/pwrgate-logger
    '';
  };
  users.extraUsers.pwrgate-logger = {
    isSystemUser = true;
    group = "pwrgate-logger";
  };
  users.extraGroups.pwrgate-logger = {};

  # Configure linkzone-logger
  sops.secrets.linkzone-logger_influx_token = {
    owner = "linkzone-logger";
    key = "logger_influx_token";
  };
  systemd.services.linkzone-logger = {
    description = "Linkzone Logger";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" "influxdb2.service" ];
    after = [ "network-online.target" "influxdb2.service" ];
    environment = {
      INFLUX_SERVER = "http://influx.isz.wtf:8086/";
    };
    unitConfig = {
      StartLimitIntervalSec = "0";
    };
    serviceConfig = {
      User = "linkzone-logger";
      Group = "linkzone-logger";
      Restart = "always";
      RestartSec = "5s";
    };
    script = ''
      export INFLUX_TOKEN="$(cat ${lib.strings.escapeShellArg config.sops.secrets.linkzone-logger_influx_token.path})"
      exec ${pkgs.callPackage ./go {}}/bin/linkzone-logger
    '';
  };
  users.extraUsers.linkzone-logger = {
    isSystemUser = true;
    group = "linkzone-logger";
  };
  users.extraGroups.linkzone-logger = {};

  # Configure dashboard
  sops.secrets."dashboard_influx_token" = {
    owner = config.services.dashboard.user;
  };
  services.dashboard = {
    enable = true;
    influxdb.tokenPath = config.sops.secrets.dashboard_influx_token.path;
  };
  # TODO: Configure esphome
  # Configure home-assistant
  # Configure zwave-js-ui
  services.zwave-js-ui = {
    enable = true;
  };
  # TODO: Configure atuin
  # TODO: Configure freepbx-app
  sops.secrets."weatherflow2mqtt_station_token" = {
    owner = config.services.weatherflow2mqtt.user;
  };
  services.weatherflow2mqtt = {
    enable = true;
    unitSystem = "imperial";
    elevation = 12.0; # meters
    inherit (config.services.home-assistant.config.homeassistant) latitude longitude;
    mqtt.host = "mqtt.isz.wtf";
    station.id = 115731;
    station.tokenPath = config.sops.secrets.weatherflow2mqtt_station_token.path;
  };

  services.nix-serve.enable = true;
  services.nix-serve.package = pkgs.nix-serve-ng;

  virtualisation.libvirtd.enable = true;

  isz.networking.vlans = [981];
  systemd.network.networks.vm-plc-guest = {
    matchConfig = {
      MACAddress = "fe:54:00:81:73:d3";
    };
    networkConfig = {
      Bridge = "br0";
      LinkLocalAddressing = "no";
    };
    bridgeVLANs = [{ PVID = 88; EgressUntagged = 88; }];
  };
  systemd.network.networks.vm-plc-profinet = {
    matchConfig = {
      MACAddress = "fe:54:00:df:c3:9a";
    };
    networkConfig = {
      Bridge = "br0";
      LinkLocalAddressing = "no";
    };
    bridgeVLANs = [{ PVID = 981; EgressUntagged = 981; }];
  };
}
