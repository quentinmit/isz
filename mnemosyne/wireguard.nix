{ config, lib, pkgs, ... }:
let
  genWg = name: {
    netdevs.${name} = {
      netdevConfig.Name = name;
      netdevConfig.Kind = "wireguard";
      netdevConfig.Description = "WireGuard tunnel to ISZ";
      wireguardConfig = {
        RouteTable = "main";
      };
      wireguardPeers = [{
        Endpoint = "c.isz.wtf:13231";
        AllowedIPs = "172.30.96.0/22";
        PublicKey = "6MJKwE/4omCc3lijBJP31qP316sIxgXUbiBzDDiEvWk=";
        PersistentKeepalive = 25;
      }];
    };
    networks.${name} = {
      matchConfig.Name = name;
      networkConfig = {
        DNS = "172.30.98.65";
        Domains = ["~isz.wtf"];
        DNSDefaultRoute = false;
      };
    };
    networks."99-ethernet-default-dhcp".networkConfig.Domains = [
      "~c.isz.wtf"
      "~."
    ];
  };
in {
  sops.secrets."wg0/private_key" = {
    group = "systemd-network";
    mode = "0440";
  };
  sops.secrets."wg0/initrd_private_key" = {
    group = "systemd-network";
    mode = "0440";
  };

  boot.initrd.secrets."/etc/credstore/network.wireguard.private.wg-initrd" = config.sops.secrets."wg0/initrd_private_key".path;
  boot.initrd.availableKernelModules = [ "wireguard" ];
  boot.initrd.systemd.network = lib.mkMerge [
    (genWg "wg-initrd")
    {
      networks.wg-initrd.networkConfig = {
        Address = "172.30.98.73/26";
        KeepConfiguration = false;
      };
    }
  ];
  boot.initrd.systemd.extraBin.ip = "${pkgs.iproute2}/bin/ip";
  boot.initrd.systemd.services.systemd-networkd.serviceConfig.ExecStopPost = [
    "-/bin/ip link delete wg-initrd"
  ];
  systemd.network = lib.mkMerge [
    (genWg "wg0")
    {
      netdevs.wg0.wireguardConfig.PrivateKeyFile = config.sops.secrets."wg0/private_key".path;
      networks.wg0.networkConfig.Address = "172.30.98.72/26";
    }
  ];
}
