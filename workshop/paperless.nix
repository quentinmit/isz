{ config, lib, pkgs, ... }:
{
  config = {
    services.paperless = {
      enable = true;
      extraConfig = {
        GUNICORN_CMD_ARGS = "--bind=unix:/run/paperless/paperless.sock";
        PAPERLESS_URL = "https://paperless.isz.wtf";
        PAPERLESS_USE_X_FORWARD_HOST = true;
        PAPERLESS_DBENGINE = "postgresql";
        PAPERLESS_DBHOST = "/run/postgresql/";
        PAPERLESS_DBNAME = config.services.paperless.user;
      };
    };
    services.postgresql = {
      ensureDatabases = [ config.services.paperless.user ];
      ensureUsers = [
        { name = config.services.paperless.user; ensureDBOwnership = true; }
      ];
    };
    systemd.services.paperless-web.serviceConfig = {
      RuntimeDirectory = "paperless";
      SystemCallFilter = [ "@chown" ];
    };
    users.users."${config.services.nginx.user}".extraGroups = [ config.services.paperless.user ];
    services.nginx = {
      upstreams.paperless.servers."unix:/run/paperless/paperless.sock" = {};
      virtualHosts."paperless.isz.wtf" = {
        forceSSL = true;
        enableACME = true;
        locations."/" = {
          proxyPass = "http://paperless";
          proxyWebsockets = true;
        };
      };
    };
  };
}
