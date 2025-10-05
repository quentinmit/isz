{ config, ... }:
{
  services.bind = {
    enable = true;
    cacheNetworks = [
      "127.0.0.0/24"
      "::1/128"
      "192.168.0.0/16"
    ];
    forwarders = [];
    zones = {
      "comclub.org" = {
        master = true;
        file = ./pri/comclub.org.zone;
      };
      "168.192.in-addr.arpa" = {
        master = true;
        file = ./pri/168.192.zone;
      };
      "hb-rights.org" = {
        master = true;
        file = ./pri/hb-rights.org.zone;
      };
    };
  };
}
