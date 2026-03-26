{ config, pkgs, lib, ... }:
let
  mkArr = name: { config, ... }: {
    sops.secrets."${name}/apikey" = {};
    sops.templates."${name}.env".content = ''
      ${lib.toUpper name}__AUTH__APIKEY=${config.sops.placeholder."${name}/apikey"}
    '';
    services.${name} = {
      enable = true;
      settings = {
        postgres.host = "/run/postgresql";
        postgres.user = name;
        postgres.maindb = name;
        log.dbenabled = false;
        server.urlbase = "/${name}";
        auth.method = "External";
    };
    environmentFiles = [config.sops.templates."${name}.env".path];
    };
    services.postgresql = {
      ensureDatabases = [ name ];
      ensureUsers = [
        { name = name; ensureDBOwnership = true; }
      ];
    };
    services.postgresqlBackup.databases = [ name ];
    services.nginx = {
      upstreams.${name}.servers."127.0.0.1:${toString config.services.${name}.settings.server.port}" = {};
      virtualHosts."arr.isz.wtf".locations."/${name}" = {
        proxyPass = "http://${name}";
        proxyWebsockets = true;
        extraConfig = config.services.nginx.virtualHosts."arr.isz.wtf".locations."/".extraConfig;
      };
    };
    systemd.services.${name}.serviceConfig.NFTSet = ["cgroup:inet:arr:cg_arr"];
  };
in {
  imports = [
    ./bitmagnet.nix
    ./container.nix
    ./exportarr.nix
    ./flaresolverr.nix
    ./nftables.nix
    ./nginx.nix
    ./transmission.nix
    (mkArr "radarr")
    (mkArr "sonarr")
    (mkArr "prowlarr")
  ];
}
