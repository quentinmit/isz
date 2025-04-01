{ config, pkgs, lib, self, ... }:
{
  systemd.network.networks."20-ve-rtorrent" = {
    name = "ve-rtorrent";
    networkConfig = {
      LinkLocalAddressing = "ipv6";
      LLDP = true;
      #EmitLLDP=customer-bridge
      IPv6AcceptRA = false;
      IPv6SendRA = false;
    };
  };
  containers.rtorrent = {
    privateNetwork = true;
    extraFlags = [
      "--network-veth"
    ];
    config = { config, pkgs, lib, ... }: {
      imports = [
        #self.nixosModules.base
      ];
      networking.useHostResolvConf = false;
      networking.useNetworkd = true;
    };
  };
}
