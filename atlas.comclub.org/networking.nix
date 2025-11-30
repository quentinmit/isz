{ config, pkgs, ... }:
{
  networking.useDHCP = false;
  networking.useNetworkd = true;
  systemd.network.netdevs.br0 = {
    netdevConfig.Name = "br0";
    netdevConfig.Kind = "bridge";
  };
  systemd.network.networks = {
    br0 = {
      name = "br0";
      networkConfig.DHCP = "ipv4";
      networkConfig.IPv4ReversePathFilter = "no";
      # TODO: networkConfig.Address = "192.168.0.254/24";
      routingPolicyRules = [{
        Family = "ipv4";
        FirewallMark = 5;
        Table = 500;
      }];
      routes = [{
        Destination = "192.168.0.5";
        Table = 500;
      }];
    };
    lo = {
      name = "lo";
      networkConfig.IPv4ReversePathFilter = "no";
      routes = [{
        Destination = "0.0.0.0/0";
        Type = "local";
        Table = 500;
      }];
    };
    bridge-physical = {
      matchConfig.Name = [
        "eno1" # Upper port
        "eth0" # VM
        "enp2s0" # Lower port
        "eth1" # VM
      ];
      networkConfig = {
        Bridge = "br0";
        LinkLocalAddressing = "no";
        LLDP = true;
        EmitLLDP = true;
      };
    };
  };
  networking = {
    nftables.enable = true;
    firewall.enable = false;
    nftables.preCheckRuleset = ''
      sed 's/skuid nginx/skuid nobody/g' -i ruleset.conf
      sed 's/meta broute set 1//g' -i ruleset.conf
    '';
    nftables.tables.filter = {
      family = "ip";
      content = ''
        chain output {
          type filter hook output priority filter;
          ip daddr 192.168.0.5 tcp dport 80 skuid ${config.services.nginx.user} counter ct mark set 5
        }
        chain setmark {
          type filter hook prerouting priority mangle; policy accept;
          ct mark 5 meta mark set ct mark counter accept
        }
      '';
    };
    nftables.tables.br = {
      family = "bridge";
      content = ''
        chain prerouting {
          type filter hook prerouting priority -250; policy accept;
          iifname "vnet*" ip saddr 192.168.0.5 tcp sport 80 counter meta broute set 1 accept
        }
      '';
    };
  };
  systemd.network.config.networkConfig.IPv4Forwarding = true;
}
