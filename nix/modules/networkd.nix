{ lib, pkgs, config, options, ... }:
let
  vlanIdType = lib.types.ints.between 1 4094;
in {
  options = with lib; {
    isz.networking = {
      lastOctet = mkOption {
        type = types.nullOr types.ints.u8;
        default = null;
      };
      macAddress = mkOption {
        type = types.strMatching "^([0-9a-fA-F]{2}\:){5}[0-9a-fA-F]{2}$";
      };
      vlans = mkOption {
        type = types.listOf vlanIdType;
      };
      pvid = mkOption {
        type = vlanIdType;
        default = 3096;
      };
      vlan88 = mkEnableOption "VLAN 88";
      linkzone = mkEnableOption "Attach Linkzone to VLAN 500";
      profinet = mkEnableOption "VLAN 981 (Profinet)";
    };
  };
  config = let
    cfg = config.isz.networking;
  in lib.mkMerge [
    (lib.mkIf (cfg.lastOctet != null) {
      isz.networking.vlans = [
        3096
        3097
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
      systemd.network.networks = let
        bridgeVLANs = builtins.map (id:
          (
            if id == cfg.pvid
            then { PVID = id; EgressUntagged = id; }
            else { VLAN = id; }
          )
        ) cfg.vlans;
      in {
        br0 = {
          name = "br0";
          networkConfig = {
            DHCP = "ipv4";
            VLAN = [
              "vlan3097"
            ];
          };
          inherit bridgeVLANs;
        };
        eth = {
          matchConfig = {
            Name = "e*";
          };
          networkConfig = {
            Bridge = "br0";
            LinkLocalAddressing = "no";
            LLDP = true;
            EmitLLDP = true;
          };
          inherit bridgeVLANs;
        };
        vlan3097 = {
          name = "vlan3097";
          networkConfig = {
            Address = "172.30.97.${toString cfg.lastOctet}/24";
          };
        };
      };
    })
    (lib.mkIf cfg.linkzone {
      isz.networking.vlans = [
        500
      ];
      environment.systemPackages = with pkgs; [
        android-tools
        (writeShellScriptBin "linkzone-debug" ''
          # https://alex.studer.dev/2021/01/04/mw41-1
          exec ${pkgs.sg3_utils}/bin/sg_raw -r 192 /dev/disk/by-id/usb-ONETOUCH_MobileBroadBand_1234567890ABCDE-0:0 16 f9 00 00 00 00 00 00 00 00 00 00 00 00 00 00 -v
        '')
      ];
      systemd.network.networks = {
        # Match USB device first even if it's named "enp*"
        "00-usb0" = {
          matchConfig = {
            # Alcatel / Mobilebroadband
            Property = "ID_USB_DRIVER=* ID_VENDOR_ID=1bbb";
            # ID_MODEL_ID=0192 when booting, ID_MODEL_ID=0908 after boot
          };
          networkConfig = {
            Bridge = "br0";
          };
          bridgeVLANs = [
            { PVID = 500; EgressUntagged = 500; }
          ];
        };
      };
    })
    (lib.mkIf cfg.vlan88 {
      isz.networking.vlans = [
        88
      ];
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
          Address = "192.168.88.${toString cfg.lastOctet}/24";
        };
      };
    })
    (lib.mkIf cfg.profinet (let
      profinetVLAN = 981;
      intf = "vlan${toString profinetVLAN}";
    in {
      isz.networking.vlans = [
        profinetVLAN
      ];
      systemd.network.networks.br0.networkConfig.VLAN = [intf];
      systemd.network.netdevs."${intf}" = {
        enable = true;
        netdevConfig = {
          Name = intf;
          Kind = "vlan";
        };
        vlanConfig = {
          Id = profinetVLAN;
        };
      };
      systemd.network.networks."${intf}" = {
        name = intf;
        networkConfig = {
          Address = "172.30.98.${toString cfg.lastOctet}/26";
        };
      };
    }))
  ];
}
