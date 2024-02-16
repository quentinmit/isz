{ config, lib, authentik, ... }:
{
  imports = [
    authentik.nixosModules.default
  ];
  config = {
    # Workaround https://github.com/goauthentik/authentik/issues/3005
    time.timeZone = lib.mkForce "America/New_York";
    systemd.services.authentik-migrate.environment.TZ = "UTC";
    systemd.services.authentik-worker.environment.TZ = "UTC";
    systemd.services.authentik.environment.TZ = "UTC";
    services.authentik = {
      enable = true;
      nginx = {
        enable = true;
        enableACME = true;
        host = "auth.isz.wtf";
      };
      settings = {
        disable_startup_analytics = true;
      };
    };
  };
}
