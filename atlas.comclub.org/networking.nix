{ config, pkgs, ... }:
{
  networking.useDHCP = false;
  networking.useNetworkd = true;
  systemd.network.netdevs.br0 = {
    netdevConfig.Name = "br0";
    netdevConfig.Kind = "bridge";
  };
  # Upper port
  systemd.network.links."00-wan0" = {
    matchConfig.OriginalName = "eno1 eth0";
    linkConfig.Name = "wan0";
  };
  systemd.network.networks = {
    br0 = {
      name = "br0";
      networkConfig.Address = "192.168.0.254/24";
    };
    # Lower port
    enp2s0 = {
      matchConfig.Name = [
        "enp2s0"
        "eth1" # VM
      ];
      networkConfig = {
        Bridge = "br0";
        LinkLocalAddressing = "no";
        LLDP = true;
        EmitLLDP = true;
      };
    };
    wan0 = {
      matchConfig.Name = "wan0";
      networkConfig = {
        DHCP = "ipv4";
      };
    };
  };
  networking = {
    nftables.enable = true;

    firewall = {
      enable = true;

      trustedInterfaces = [ "br0" ];

      interfaces.wan0 = {
        allowedTCPPorts = [
          80 # http
          25 # smtp
          22 # ssh
          993 # imaps
          587 # submission
        ];
        allowedUDPPortRanges = [
          # Mosh
          { from = 60000; to=61000; }
        ];
      };
    };

    nat = {
      enable = true;

      internalInterfaces = [ "br0" ];

      internalIPs = [ "192.168.0.0/24" ];

      externalInterface = "eth0";

      forwardPorts = [
        {
          sourcePort = 8081;
          destination = "192.168.0.5:80";
          proto = "tcp";
        }
      ];
    };
  };
}
