{ config, pkgs, ... }:
{
  services.homebox = {
    enable = true;
    package = pkgs.unstable.homebox;
    database.createLocally = true;
    settings = {
      HBOX_WEB_HOST = "unix?path=%t/homebox/homebox.sock";
      HBOX_OPTIONS_ALLOW_ANALYTICS = "false";
      HBOX_OPTIONS_TRUST_PROXY = "true";
      HBOX_WEB_MAX_UPLOAD_SIZE = "256";
    };
  };
  systemd.services.homebox.serviceConfig.RuntimeDirectory = "homebox";
  services.nginx = {
    upstreams.homebox.servers."unix:/run/homebox/homebox.sock" = {};
    virtualHosts."homebox.isz.wtf" = {
      forceSSL = true;
      enableACME = true;
      locations."/".proxyPass = "http://homebox";
    };
  };
}
