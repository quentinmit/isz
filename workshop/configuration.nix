# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "workshop"; # Define your hostname.

  networking.useDHCP = false;
  networking.useNetworkd = true;
  systemd.network.netdevs = {
    br0 = {
      enable = true;
      name = "br0";
      Kind = "bridge";
      MACAddress = "04:42:1A:C9:93:8B";
      extraConfig = {
        "[Bridge]";
        "VLANFiltering=yes";
        "STP=no";
        "DefaultPVID=none";
      };
    };
    vlan88 = {
      enable = true;
      name = "vlan88";
      Kind = "vlan";
      vlanConfig = {
        Id = 88;
      };
    };
    vlan3097 = {
      enable = true;
      name = "vlan3097";
      Kind = "vlan";
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
        VLAN = {
          3097;
          88;
        };
      };
      extraConfig = {
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
    };
    eth = {
      matchConfig = {
        Name = "e*";
      };
      networkConfig = {
        LinkLocalAddressing = "none";
      };
      extraConfig = {
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
    };
    usb0 = {
      name = "usb0";
      networkConfig = {
        Bridge = "br0";
        extraConfig = {
          ''
            [BridgeVLAN]
            PVID=500
            EgressUntagged=500
          '';
        };
      };
    };
    vlan3097 = {
      name = "vlan3097";
      networkConfig = {
        Address = "172.30.97.32/24";
        VLAN = 3097;
      };
    };
    vlan88 = {
      name = "vlan88";
      networkConfig = {
        Address = "192.168.88.32";
        VLAN = 88;
      };
    };
  };

  # Set your time zone.
  time.timeZone = "America/New_York";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
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
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    emacs
    wget
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

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

}
