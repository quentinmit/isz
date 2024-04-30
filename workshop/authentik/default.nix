{ config, lib, pkgs, authentik, ... }:
{
  imports = [
    authentik.nixosModules.default
    ./blueprint.nix
    ./apps
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
        redisSocketUrl = "redis+socket://${config.services.redis.servers.authentik.unixSocket}?db=0";
      in {
        error_reporting.enabled = false;
        disable_update_check = true;
        disable_startup_analytics = true;
        avatars = "gravatar,initials";
        # https://github.com/jazzband/django-redis#configure-as-cache-backend
        cache.url = redisUrl;
        channel.url = redisUrl;
        # https://docs.celeryq.dev/en/stable/userguide/configuration.html#redis-backend-settings
        broker.url = redisSocketUrl;
        result_backend.url = redisSocketUrl;
        # Disable outpost discovery since there's no Kubernetes or Docker.
        outposts.discover = false;
      };

      # Fix for newer unstable NixOS
      authentikComponents = let
        scope = (authentik.lib.mkAuthentikScope { pkgs = pkgs.unstable; }).overrideScope (final: prev: {
          nodejs_21 = pkgs.unstable.nodejs_22;
        });
        in scope.authentikComponents;
    };
    isz.telegraf.prometheus.apps.authentik = {
      url = "http://localhost:9300/metrics";
      extraConfig.http_headers.Accept = "text/plain";
    };
  };
}
