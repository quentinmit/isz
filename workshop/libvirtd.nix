{ config, channels, lib, pkgs, ... }:
{
  disabledModules = [
    "virtualisation/libvirtd.nix"
  ];
  imports = [
    "${channels.unstable}/nixos/modules/virtualisation/libvirtd.nix"
  ];
  isz.networking.vlans = [981 983];
  systemd.network.networks.vm-plc-guest = {
    matchConfig = {
      MACAddress = "fe:54:00:81:73:d3";
    };
    networkConfig = {
      Bridge = "br0";
      LinkLocalAddressing = "no";
    };
    bridgeVLANs = [{ PVID = 88; EgressUntagged = 88; }];
  };
  systemd.network.networks.vm-plc-profinet = {
    matchConfig = {
      MACAddress = "fe:54:00:df:c3:9a";
    };
    networkConfig = {
      Bridge = "br0";
      LinkLocalAddressing = "no";
    };
    bridgeVLANs = [{ PVID = 981; EgressUntagged = 981; }];
  };
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

  virtualisation.libvirtd = {
    enable = true;
    package = pkgs.unstable.libvirt.overrideAttrs (old: {
      patches = old.patches or [] ++ [
        ../nix/pkgs/libvirt/m68k.patch
      ];
    });
  };
}
