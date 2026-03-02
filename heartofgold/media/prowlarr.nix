{ config, pkgs, lib, ... }:
{
  services.prowlarr = {
    enable = true;
    settings = {
      postgres.host = "/run/postgresql";
      postgres.user = "prowlarr";
      postgres.maindb = "prowlarr";
      log.dbenabled = false;
      server.urlbase = "/prowlarr";
      auth.method = "External";
    };
  };
  services.postgresql = {
    ensureDatabases = [ "prowlarr" ];
    ensureUsers = [
      { name = "prowlarr"; ensureDBOwnership = true; }
    ];
  };
  services.nginx = {
    upstreams.prowlarr.servers."127.0.0.1:9696" = {};
    virtualHosts."arr.isz.wtf".locations."/prowlarr" = {
      proxyPass = "http://prowlarr";
      proxyWebsockets = true;
      extraConfig = config.services.nginx.virtualHosts."arr.isz.wtf".locations."/".extraConfig;
    };
  };
  systemd.services.prowlarr.serviceConfig.NFTSet = ["cgroup:inet:arr:cg_arr"];
}
