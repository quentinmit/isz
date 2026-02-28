{ config, pkgs, lib, ... }:
{
  services.sonarr = {
    enable = true;
    settings = {
      postgres.host = "/run/postgresql";
      postgres.user = "sonarr";
      postgres.maindb = "sonarr";
      log.dbenabled = false;
    };
  };
  services.postgresql = {
    ensureDatabases = [ "sonarr" ];
    ensureUsers = [
      { name = "sonarr"; ensureDBOwnership = true; }
    ];
  };
}
