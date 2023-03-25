{ lib, pkgs, config, options, ... }:
{
  options = with lib; {
    isz.networking = {
      lastOctet = mkOption {
        type = types.ints.u8;
      };
      macAddress = mkOption {
        type = types.strMatching "^([0-9a-fA-F]{2}\:){5}[0-9a-fA-F]{2}$";
      };
      vlan88 = mkEnableOption "VLAN 88";
    };
  };
  config = let cfg = config.isz.networking; in with lib.strings; {
    networking.useDHCP = false;
    networking.useNetworkd = true;
    systemd.network.netdevs = {
      br0 = {
        enable = true;
        netdevConfig = {
          Name = "br0";
          Kind = "bridge";
          MACAddress = cfg.macAddress;
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
          Address = "172.30.97.${toString cfg.lastOctet}/24";
        };
      };
      vlan88 = lib.mkIf cfg.vlan88 {
        name = "vlan88";
        networkConfig = {
          Address = "192.168.88.${toString cfg.lastOctet}";
        };
      };
    };
  };
}
