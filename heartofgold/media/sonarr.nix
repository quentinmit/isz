{ config, pkgs, lib, ... }:
{
  services.sonarr = {
    enable = true;
    settings = {
      postgres.host = "/run/postgresql";
      postgres.user = "sonarr";
      postgres.maindb = "sonarr";
      log.dbenabled = false;
      server.urlbase = "/sonarr";
    };
  };
  services.postgresql = {
    ensureDatabases = [ "sonarr" ];
    ensureUsers = [
      { name = "sonarr"; ensureDBOwnership = true; }
    ];
  };
  services.nginx = {
    upstreams.sonarr.servers."127.0.0.1:8989" = {};
    virtualHosts."arr.isz.wtf".locations."/sonarr" = {
      proxyPass = "http://sonarr";
      proxyWebsockets = true;
      extraConfig = config.services.nginx.virtualHosts."arr.isz.wtf".locations."/".extraConfig;
    };
  };
}
