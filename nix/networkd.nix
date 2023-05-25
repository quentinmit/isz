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
  config = let
    cfg = config.isz.networking;
  in lib.mkMerge [
    {
      environment.systemPackages = with pkgs; [
        (writeScriptBin "linkzone-debug" ''
          # https://alex.studer.dev/2021/01/04/mw41-1
          exec ${pkgs.sg3_utils}/bin/sg_raw -r 192 /dev/disk/by-id/usb-ONETOUCH_MobileBroadBand_1234567890ABCDE-0:0 16 f9 00 00 00 00 00 00 00 00 00 00 00 00 00 00 -v
        '')
      ];
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
        # Match USB devices first even if they're named "enp*"
        "00-usb0" = {
          matchConfig = {
            Property = "ID_USB_DRIVER=*";
          };
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
        vlan3097 = {
          name = "vlan3097";
          networkConfig = {
            Address = "172.30.97.${toString cfg.lastOctet}/24";
          };
        };
      };
    }
    (lib.mkIf cfg.vlan88 {
      systemd.network.networks.br0.networkConfig.VLAN = ["vlan88"];
      systemd.network.netdevs.vlan88 = {
        enable = true;
        netdevConfig = {
          Name = "vlan88";
          Kind = "vlan";
        };
        vlanConfig = {
          Id = 88;
        };
      };
      systemd.network.networks.vlan88 = {
        name = "vlan88";
        networkConfig = {
          Address = "192.168.88.${toString cfg.lastOctet}";
        };
      };
    })
  ];
}
