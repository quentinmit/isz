{ config, lib, pkgs, ... }:
{
  config = {
    security.acme.acceptTerms = true;
    security.acme.defaults.email = "qsmith@gmail.com";
    services.nginx = {
      enable = true;
      additionalModules = with pkgs.nginxModules; [
        vts
      ];
      appendHttpConfig = ''
        vhost_traffic_status_zone;
      '';
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;
      recommendedProxySettings = true;
      virtualHosts."arr.isz.wtf" = {
        forceSSL = true;
        enableACME = true;
        authentik.enable = true;
        authentik.url = "https://auth.isz.wtf:9443";
      };
    };
  };
}
