# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./nginx.nix
      ./home-assistant.nix
      ../nix/zwave-js-ui.nix
      ../nix/base.nix
      ../nix/rtlamr.nix
      ../nix/speedtest.nix
    ];

  sops.defaultSopsFile = ./secrets.yaml;

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi = {
    efiSysMountPoint = "/boot/efi";
    canTouchEfiVariables = true;
  };

  networking.hostName = "workshop"; # Define your hostname.

  isz.openssh = {
    hostKeyTypes = ["ecdsa" "ed25519" "rsa"];
    useSops = true;
  };

  networking.useDHCP = false;
  networking.useNetworkd = true;
  systemd.network.netdevs = {
    br0 = {
      enable = true;
      netdevConfig = {
        Name = "br0";
        Kind = "bridge";
        MACAddress = "04:42:1A:C9:93:8B";
      };
      extraConfig =
        ''
          [Bridge]
          VLANFiltering=yes
          STP=no
          DefaultPVID=none
        '';
    };
    vlan88 = {
      enable = true;
      netdevConfig = {
        Name = "vlan88";
        Kind = "vlan";
      };
      vlanConfig = {
        Id = 88;
      };
    };
    vlan3097 = {
      enable = true;
      netdevConfig = {
        Name = "vlan3097";
        Kind = "vlan";
      };
      vlanConfig = {
        Id = 3097;
      };
    };
  };
  systemd.network.networks = {
    br0 = {
      name = "br0";
      networkConfig = {
        DHCP = "ipv4";
        VLAN = [
          "vlan3097"
          "vlan88"
        ];
      };
      extraConfig =
        ''
          [BridgeVLAN]
          PVID=3096
          EgressUntagged=3096
          [BridgeVLAN]
          VLAN=3097
          [BridgeVLAN]
          VLAN=500
          [BridgeVLAN]
          VLAN=88
        '';
    };
    eth = {
      matchConfig = {
        Name = "e*";
      };
      networkConfig = {
        Bridge = "br0";
        LinkLocalAddressing = "no";
      };
      extraConfig =
        ''
          [BridgeVLAN]
          PVID=3096
          EgressUntagged=3096
          [BridgeVLAN]
          VLAN=3097
          [BridgeVLAN]
          VLAN=500
          [BridgeVLAN]
          VLAN=88
        '';
    };
    usb0 = {
      name = "usb0";
      networkConfig = {
        Bridge = "br0";
      };
      extraConfig =
        ''
          [BridgeVLAN]
          PVID=500
          EgressUntagged=500
        '';
    };
    vlan3097 = {
      name = "vlan3097";
      networkConfig = {
        Address = "172.30.97.34/24";
      };
    };
    vlan88 = {
      name = "vlan88";
      networkConfig = {
        Address = "192.168.88.34";
      };
    };
  };

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
  ];

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

  # TODO: Configure udev for Zwave, Fluke45, PWRGate
  # Configure mosquitto
  services.mosquitto = {
    enable = true;
    listeners = [ {
      acl = [ "pattern readwrite #" ];
      omitPasswordAuth = true;
      settings.allow_anonymous = true;
      # TODO: Restrict to 172.30.96.0/24 and 192.168.88.0/24
      # TODO: Enable SSL/WebSockets
    } ];
  };
  # TODO: Configure tftp
  # TODO: Configure postfix
  # Containers?
  # Configure rtl-sdr to hotplug on udev 0bda/2838
  services.rtl-tcp.enable = true;
  # Configure rtlamr
  sops.secrets.rtlamr_influx_token = {};
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
    logLevel = "trace";
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
  services.grafana = {
    enable = true;
    settings = {
      server.protocol = "socket";
    };
  };
  # TODO: Configure pwrgate-logger
  # TODO: Configure linkzone-logger
  # TODO: Configure services.telegraf
  # Configure speedtest
  sops.secrets."speedtest_influx_password" = {};
  services.speedtest-influxdb = {
    enable = true;
    influxdb = {
      url = "http://influx.isz.wtf:8086/";
      username = "speedtest";
      passwordPath = config.sops.secrets.speedtest_influx_password.path;
      db = "speedtest";
    };
    interval = 3600;
    showExternalIp = true;
  };
  # TODO: Configure dashboard (for esphome)
  # TODO: Configure esphome
  # Configure home-assistant
  # Configure zwave-js-ui
  services.zwave-js-ui = {
    enable = true;
  };
  # TODO: Configure postgres
  # TODO: Configure atuin
  # TODO: Configure freepbx-app
}
