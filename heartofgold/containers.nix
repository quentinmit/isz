{ config, pkgs, lib, self, specialArgs, ... }:
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
  systemd.services."container@rtorrent" = let
    requires = ["home-quentin-hog\\x2ddata.mount"];
  in {
    inherit requires;
    after = requires;
  };

  containers.rtorrent = {
    privateNetwork = true;
    extraFlags = [
      "--network-veth"
    ];
    bindMounts."/srv/private" = {
      hostPath = "/home/quentin/hog-data/quentin/private/";
      mountPoint = "/srv/private";#:owneridmap";
      isReadOnly = false;
    };
    inherit specialArgs;
    config = { config, pkgs, lib, ... }: {
      imports = [
        self.overlayModule
        self.nixosModules.base
      ];
      networking.useHostResolvConf = false;
      networking.useNetworkd = true;
      networking.firewall.enable = false;

      system.stateVersion = "24.11";

      users.users.quentin = {
        isNormalUser = true;
        description = "Quentin Smith";
      };

      home-manager.users.quentin = lib.mkMerge [
        {
          home.stateVersion = "24.05";

          isz.base = true;
        }
        # rtorrent
        {
          programs.rtorrent = {
            enable = true;
            extraConfig = ''
              upload_rate = 1000
              session = /srv/private/rtorrent-session
              port_random = yes
              dht = auto
              dht_port = 6882
              network.local_address.set = "127.0.0.1"
            '';
          };
        }
      ];
    };
  };
}
