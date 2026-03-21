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
  networking.domain = "appletalk.isz.wtf";

  networking.useDHCP = false;
  networking.useNetworkd = true;
  networking.firewall.enable = false;

  systemd.network.netdevs.piscsi_bridge = {
    enable = true;
    netdevConfig = {
      Name = "piscsi_bridge";
      Kind = "bridge";
      MACAddress = "dc:a6:32:75:54:dc";
    };
    bridgeConfig = {
      STP = "no";
    };
  };
  systemd.network.networks = {
    piscsi_bridge = {
      name = "piscsi_bridge";
      networkConfig = {
        DHCP = "ipv4";
      };
    };
    eth = {
      matchConfig = {
        Name = "e*";
      };
      networkConfig = {
        Bridge = "piscsi_bridge";
        LinkLocalAddressing = "no";
        LLDP = true;
        EmitLLDP = true;
      };
    };
  };

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

