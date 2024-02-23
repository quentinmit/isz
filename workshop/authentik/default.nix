{ config, lib, pkgs, authentik, ... }:
{
  imports = [
    authentik.nixosModules.default
    ./blueprint.nix
    ./grafana.nix
    ./bluechips.nix
  ];
  config = {
    sops.secrets."authentik/environment" = {
      restartUnits = [
        "authentik-migrate.service"
        "authentik-worker.service"
        "authentik.service"
      ];
    };
    systemd.services = lib.genAttrs [ "authentik-migrate" "authentik-worker" "authentik" ] (name: {
      serviceConfig.SupplementaryGroups = [
        config.services.redis.servers.authentik.user
      ];
    });
    services.authentik = {
      enable = true;
      environmentFile = config.sops.secrets."authentik/environment".path;
      nginx = {
        enable = true;
        enableACME = true;
        host = "auth.isz.wtf";
      };
      settings = let
        redisUrl = "unix://${config.services.redis.servers.authentik.unixSocket}?db=0";
      in {
        disable_startup_analytics = true;
        avatars = "gravatar,initials";
        cache.url = redisUrl;
        channel.url = redisUrl;
        broker.url = redisUrl;
        result_backend.url = redisUrl;
      };
    };
    isz.telegraf.prometheus.apps.authentik = {
      url = "http://localhost:9300/metrics";
      extraConfig.http_headers.Accept = "text/plain";
    };
  };
}
