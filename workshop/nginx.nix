{ lib, pkgs, config, ... }:
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
      upstreams.grafana.servers."unix:/${config.services.grafana.settings.server.socket}" = {};
      upstreams.influx.servers."localhost:8086" = {};
      upstreams.homeassistant.servers."[::1]:${toString config.services.home-assistant.config.http.server_port}" = {};
      upstreams.zwave.servers."127.0.0.1:8091" = {};
      upstreams.dashboard.servers."127.0.0.1:8080" = {};
      upstreams.jellyfin.servers."172.30.96.101:8096" = {};
      virtualHosts = {
        "workshop.isz.wtf" = {
          serverAliases = [
            "localhost"
          ];
          locations."/status" = {
            extraConfig = ''
              vhost_traffic_status_display;
              vhost_traffic_status_display_format html;

              access_log off;
              allow 127.0.0.1;
              ${lib.optionalString config.networking.enableIPv6 "allow ::1;"}
              allow 172.30.96.0/22;
              deny all;
            '';
          };
        };
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
          locations."@influx".proxyPass = "http://influx";
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
          locations = {
            "/".tryFiles = "$uri @hass";
            "@hass" = {
              proxyPass = "http://homeassistant";
              proxyWebsockets = true;
              extraConfig = ''
                proxy_buffering off;
              '';
            };
            "/zwave/" = {
              proxyPass = "http://zwave";
              proxyWebsockets = true;
              extraConfig = ''
                rewrite ^ $request_uri;
                rewrite '^/zwave(/.*)$' $1 break;
                proxy_set_header X-External-Path /zwave;
              '';
            };
            "/dashboard/" = lib.mkIf config.services.dashboard.enable {
              proxyPass = "http://dashboard";
              extraConfig = ''
                rewrite '^/dashboard(/.*)$' $1 break;
              '';
            };
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
            proxyPass = "http://jellyfin";
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
