{ config, lib, pkgs, ... }:
{
  isz.networking.vlans = [983];

  systemd.network.networks.vm-globaltalk = {
    matchConfig = {
      MACAddress = "fe:00:07:9c:c5:e6";
    };
    networkConfig = {
      Bridge = "br0";
      LinkLocalAddressing = "no";
    };
    bridgeVLANs = [{ PVID = 983; EgressUntagged = 983; }];
  };
}
