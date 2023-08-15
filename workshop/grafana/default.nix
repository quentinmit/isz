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
    };
    services.grafana = {
      enable = true;
      package = pkgs.unstable.grafana;
      settings = {
        server.protocol = "socket";
        security.allow_embedding = true;
        feature_toggles.enable = "timeSeriesTable";
        dataproxy.timeout = 300;
        plugins.allow_loading_unsigned_plugins = "operato-windrose-panel";
      };
      declarativePlugins = with pkgs.grafanaPlugins; [
        fetzerch-sunandmoon-datasource
        grafana-worldmap-panel
        marcusolsson-json-datasource
        mxswat-separator-panel
        operato-windrose-panel
      ];
    };
  };
}
