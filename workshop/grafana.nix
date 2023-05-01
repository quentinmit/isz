{ config, pkgs, lib, ... }:

{
  config = {
    sops.secrets."grafana/influx_token" = {
      owner = config.systemd.services.grafana.serviceConfig.User;
    };
    sops.secrets."grafana/influxql_password" = {
      owner = config.systemd.services.grafana.serviceConfig.User;
    };
    services.grafana = {
      enable = true;
      settings = {
        server.protocol = "socket";
        security.allow_embedding = true;
      };
      provision.enable = true;
      provision.datasources.settings.datasources = [
        {
          uid = "mAU691fGz";
          name = "workshop";
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
        }
        {
          uid = "-v4RrpJMk";
          name = "InfluxDB-InfluxQL";
          type = "influxdb";
          url = "http://172.30.97.34:8086";
          user = "grafana";
          database = "rtlamr";
          basicAuth = false;
          jsonData.httpMode = "POST";
          secureJsonData = {
            password = "$__file{${config.sops.secrets."grafana/influxql_password".path}}";
          };
        }
        {
          uid = "A5G--UYMz";
          orgId = 1;
          name = "Sun and Moon";
          type = "fetzerch-sunandmoon-datasource";
          jsonData = {
            latitude = 42.3687761;
            longitude = -71.0947244;
          };
        }
      ];
      provision.dashboards.settings.providers = let
        dashboards = {
          "provisioning-test" = {
            uid = "Pd7zBps4z";
            title = "Provisioning Test 2";
            panels = [{
              title = "Panel Title 2";
              type = "timeseries";
              gridPos = {
                x = 0; y = 0; w = 12; h = 8;
              };
            }];
          };
        };
        dashboardFiles = lib.mapAttrsToList (name: d: (pkgs.writeTextFile {
          name = "${name}.yaml";
          text = builtins.toJSON d;
        })) dashboards;
      in [{
          options.path = "${pkgs.linkFarmFromDrvs "grafana-dashboards" dashboardFiles}";
        }];
    };
  };
}
