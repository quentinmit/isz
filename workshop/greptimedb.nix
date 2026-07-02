{ config, lib, pkgs, ... }:
{
  services.greptimedb = {
    enable = true;
  };
  services.nginx = {
    upstreams.greptimedb.servers."localhost:4000" = {};
    virtualHosts."greptimedb.isz.wtf" = {
      forceSSL = true;
      enableACME = true;
      locations."/" = {
        proxyPass = "http://greptimedb";
        proxyWebsockets = true;
        # TODO: Configure authentication and allow external access
        extraConfig = ''
          proxy_buffering off;
          allow 172.30.96.0/23;
          deny all;
        '';
      };
    };
  };
}
