{ config, pkgs, lib, ... }:

{
  imports = [
    ./dashboards
  ];
  config = {
    sops.secrets."grafana/influx_token" = {
      owner = config.systemd.services.grafana.serviceConfig.User;
    };
    sops.secrets."grafana/influxql_password" = {
      owner = config.systemd.services.grafana.serviceConfig.User;
    };

    isz.grafana.datasources = {
      workshop = {
        uid = "mAU691fGz";
        type = "influxdb";
        url = "http://172.30.97.34:8086";
        isDefault = true;
        basicAuth = false;
        jsonData = {
          defaultBucket = "icestationzebra";
          httpMode = "POST";
          organization = "44ff94dc2f766f90";
          version = "Flux";
        };
        secureJsonData = {
          token = "$__file{${config.sops.secrets."grafana/influx_token".path}}";
        };
      };
      InfluxDB-InfluxQL = {
        uid = "-v4RrpJMk";
        type = "influxdb";
        url = "http://172.30.97.34:8086";
        user = "grafana";
        database = "rtlamr";
        basicAuth = false;
        jsonData.httpMode = "POST";
        secureJsonData = {
          password = "$__file{${config.sops.secrets."grafana/influxql_password".path}}";
        };
      };
      "Sun and Moon" = {
        uid = "A5G--UYMz";
        orgId = 1;
        name = "Sun and Moon";
        type = "fetzerch-sunandmoon-datasource";
        jsonData = {
          latitude = 42.3687761;
          longitude = -71.0947244;
        };
      };
      MQTT = {
        uid = "a90e8f00-e24a-4a3e-9f9c-b905ca44db2a";
        type = "grafana-mqtt-datasource";
        jsonData = {
          uri = "tcp://mqtt.isz.wtf:1883";
        };
      };
      loki = {
        uid = "bdxjgkarhgs8wd";
        type = "loki";
        url = "https://loki.isz.wtf";
        jsonData.oauthPassThru = true;
        jsonData.derivedFields = [
          {
            matcherRegex = "macaddress";
            matcherType = "label";
            name = "MAC address";
            url = ''/d/eXssGz84k/wifi-client?orgId=1&var-macaddress=$''${__value.raw}'';
            urlDisplayLabel = "View";
          }
        ];
      };
    };
    services.grafana = {
      enable = true;
      package = pkgs.unstable.grafana;
      settings = {
        server.protocol = "socket";
        server.root_url = "https://grafana.isz.wtf";
        security.allow_embedding = true;
        feature_toggles.enable = "timeSeriesTable";
        feature_toggles.preinstallAutoUpdate = false;
        dataproxy.timeout = 300;
        plugins.allow_loading_unsigned_plugins = "operato-windrose-panel";
        news.news_feed_enabled = false;
      };
      declarativePlugins = with pkgs.grafanaPlugins; [
        fetzerch-sunandmoon-datasource
        grafana-worldmap-panel
        marcusolsson-json-datasource
        operato-windrose-panel
        grafana-mqtt-datasource
        volkovlabs-echarts-panel
        grafana-lokiexplore-app
        grafana-pyroscope-app
      ];
    };
  };
}
