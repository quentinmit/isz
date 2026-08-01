{ config, lib, pkgs, ... }:
{
  config = {
    services.spoolman = {
      enable = true;
      environment = {
        SPOOLMAN_DB_TYPE = "postgres";
        SPOOLMAN_DB_HOST = "/run/postgresql/";
        SPOOLMAN_DB_NAME = "spoolman";
        SPOOLMAN_DB_USERNAME = "spoolman";
      };
    };
    services.postgresql = {
      ensureDatabases = [ "spoolman" ];
      ensureUsers = [
        { name = "spoolman"; ensureDBOwnership = true; }
      ];
    };

    users.users.spoolman = {
      isSystemUser = true;
      group = "spoolman";
    };
    users.groups.spoolman = {};

    systemd.services.spoolman.serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "spoolman";
      RuntimeDirectory = "spoolman";
      ExecStart = lib.mkForce "${pkgs.spoolman}/bin/spoolman --uds /run/spoolman/spoolman.sock --forwarded-allow-ips '*' --proxy-headers";
    };

    users.users."${config.services.nginx.user}".extraGroups = [ "spoolman" ];

    services.nginx = {
      upstreams.spoolman.servers."unix:/run/spoolman/spoolman.sock" = {};
      virtualHosts."spoolman.isz.wtf" = {
        forceSSL = true;
        enableACME = true;
        locations."/" = {
          proxyPass = "http://spoolman";
          proxyWebsockets = true;
        };
      };
    };

    services.authentik.apps.spoolman = {
      name = "Spoolman";
      type = "proxy";
      host = "spoolman.isz.wtf";
      nginx = true;
    };
  };
}
