{ lib, pkgs, config, ... }:
{
  config = {
    security.acme.acceptTerms = true;
    security.acme.defaults.email = "qsmith@gmail.com";
    services.nginx = {
      enable = true;
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;
      recommendedProxySettings = true;
      upstreams.grafana.servers."unix:/${config.services.grafana.settings.server.socket}" = {};
      virtualHosts = {
        "grafana.isz.wtf" = lib.mkIf config.services.grafana.enable {
          forceSSL = true;
          enableACME = true;
          locations."/".tryFiles = "$uri @grafana";
          locations."@grafana" = {
            proxyPass = "http://grafana";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_buffering off;
            '';
          };
        };
        "influx.isz.wtf" = lib.mkIf config.services.influxdb2.enable {
          forceSSL = true;
          enableACME = true;
          locations."/".tryFiles = "$uri @influx";
          locations."@influx".proxyPass = "http://localhost:8086";
        };
        "atuin.isz.wtf" = lib.mkIf false {
          forceSSL = true;
          enableACME = true;
          locations."/".proxyPass = "http://localhost:8888";
        };
        "homeassistant.isz.wtf" = lib.mkIf config.services.home-assistant.enable {
          serverAliases = [ "hass.isz.wtf" ];
          forceSSL = true;
          enableACME = true;
          locations."/".tryFiles = "$uri @hass";
          locations."@hass" = {
            proxyPass = "http://[::1]:${toString config.services.home-assistant.config.http.server_port}";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_buffering off;
            '';
          };
          locations."/zwave/" = {
            proxyPass = "http://127.0.0.1:8091";
            proxyWebsockets = true;
            extraConfig = ''
              rewrite ^ $request_uri;
              rewrite '^/zwave(/.*)$' $1 break;
              proxy_set_header X-External-Path /zwave;
            '';
          };
          locations."/dashboard/" = lib.mkIf config.services.dashboard.enable {
            proxyPass = "http://127.0.0.1:8080";
          };
        };
        "esphome.isz.wtf" = lib.mkIf false {
          forceSSL = true;
          enableACME = true;
          locations."/" = {
            proxyPass = "http://localhost:6052";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_buffering off;
            '';
          };
        };
        # TODO: "pbx.isz.wtf" = {};
        "jellyfin.isz.wtf" = {
          forceSSL = true;
          enableACME = true;
          locations."/" = {
            proxyPass = "http://172.30.96.101:8096";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_buffering off;
            '';
          };
        };
      };
    };
  };
}
