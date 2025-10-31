{ config, pkgs, lib, nixpkgs, nixos-avf, ... }:
{
  imports = [
    nixos-avf.nixosModules.avf
  ];

  nixpkgs.hostPlatform = "aarch64-linux";

  sops.defaultSopsFile = ./secrets.yaml;

  system.stateVersion = "25.05";

  services.openssh.ports = [
    22
    2222
  ];

  isz.openssh = {
    hostKeyTypes = ["ecdsa" "ed25519" "rsa"];
    useSops = true;
  };

  networking.hostName = "pixel-9-pro-xl-linux";
  networking.domain = "wg.isz.wtf";

  avf.defaultUser = "quentin";

  nix.settings.trusted-users = [ "root" "quentin" ];

  users.users.quentin = {
    description = "Quentin Smith";
  };
  home-manager.users.quentin = lib.mkMerge [
    {
      home.stateVersion = "25.05";
      isz.quentin.enable = true;
      isz.quentin.texlive = false; # Massive
      isz.quentin.radio.enable = false; # No point without USB support
    }
  ];

  sops.secrets."wg0/private_key" = {
    mode = "0440";
    group = "systemd-network";
  };
  systemd.network.netdevs.wg0 = {
    netdevConfig.Name = "wg0";
    netdevConfig.Kind = "wireguard";
    netdevConfig.Description = "WireGuard tunnel to ISZ";
    netdevConfig.MTUBytes = 1350; # Default 1420 doesn't work on 5G
    wireguardConfig = {
      PrivateKeyFile = config.sops.secrets."wg0/private_key".path;
      RouteTable = "main";
    };
    wireguardPeers = [{
      Endpoint = "c.isz.wtf:13231";
      AllowedIPs = "172.30.96.0/22";
      PublicKey = "6MJKwE/4omCc3lijBJP31qP316sIxgXUbiBzDDiEvWk=";
      PersistentKeepalive = 25;
    }];
  };
  systemd.network.networks."99-ethernet-default-dhcp" = {
    networkConfig = {
      Domains = ["~c.isz.wtf" "~p.isz.wtf" "~icestationzebra.isz.wtf"];
      DNSDefaultRoute = true;
    };
  };
  systemd.network.networks.wg0 = {
    matchConfig.Name = "wg0";
    networkConfig = {
      Address = "172.30.98.70/26";
      DNS = "172.30.98.65";
      Domains = ["~isz.wtf"];
      DNSDefaultRoute = false;
    };
  };
}
