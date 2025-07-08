{ lib, pkgs, config, options, ... }:
{
  config = let
    pingTargets = [{ host = "overwatch.mit.edu"; }] ++ (builtins.fromJSON (builtins.readFile ../telegraf/static/he_lg.json)).he_lg_ping_targets;
  in {
    isz.telegraf = {
      enable = true;
      intelRapl = true;
      amdgpu = true;
      openweathermap = {
        appId = "$OPENWEATHERMAP_APP_ID";
        cityIds = ["4931972" "4930956" "5087559"];
      };
      mikrotik.api = let defaults = {
        plaintext = true;
        user = "$MIKROTIK_API_USER";
        password = "$MIKROTIK_API_PASSWORD";
      }; in {
        targets = map (t: defaults // t) [
          { ip = "172.30.97.3"; }
          { ip = "172.30.97.20"; }
        ];
      };
      mikrotik.swos = let defaults = {
        user = "$MIKROTIK_SWOS_USER";
        password = "$MIKROTIK_SWOS_PASSWORD";
      }; in {
        targets = map (t: defaults // t) [
          { ip = "172.30.97.16"; }
          { ip = "172.30.97.17"; }
          { ip = "172.30.97.18"; }
        ];
      };
      mikrotik.snmp.targets = [
        { ip = "172.30.97.3"; }
        { ip = "172.30.97.16"; }
        { ip = "172.30.97.17"; }
        { ip = "172.30.97.18"; }
        { ip = "172.30.97.20"; }
      ];
      prometheus.apps = {
        grafana.url = "https://grafana.isz.wtf/metrics";
        influx.url = "https://influx.isz.wtf/metrics";
        meshradio = {
          url = "http://172.30.97.21:9100/metrics";
          tags = {
            agent_host = "172.30.97.21";
            hostname = "meshradio";
          };
        };
        workshop-kvm = {
          url = "http://172.30.97.38/metrics";
          tags = {
            agent_host = "172.30.97.38";
            hostname = "workshop-kvm";
            app = "jetkvm";
          };
        };
      };
      hitron.targets = [
        { ip = "192.168.100.1"; }
      ];
      postgresql = true;
      netflow.enable = true;
    };
    services.telegraf.extraConfig = lib.mkMerge [
      {
        outputs.socket_writer = [{
          namepass = ["netflow_raw"];
          address = "unixgram:///run/vector/telegraf_netflow.sock";
          data_format = "json";
        }];
      }
      {
        inputs.nginx_vts = [{
          urls = ["http://localhost/status/format/json"];
        }];
      }
      {
        inputs.ping = [{
          interval = "30s";
          method = "native";
          urls = map (t: t.host) pingTargets;
          ipv6 = false;
        }];
        processors.starlark = [{
          namepass = ["ping"];
          source = ''
            tags = ${builtins.toJSON (builtins.listToAttrs (map (value: { name = value.host; inherit value; }) pingTargets))}
            def apply(metric):
              url = metric.tags.get("url")
              extra = tags.get(url)
              if extra:
                extra = dict(extra)
                extra.pop("host")
                if "exchanges" in extra:
                  extra["exchanges"] = ", ".join(extra["exchanges"])
                metric.tags.update(extra)
              return metric
          '';
        }];
      }
      {
        inputs.mqtt_consumer = [{
          alias = "weatherflow";
          name_prefix = "weatherflow_";
          tags.influxdb_bucket = "weatherflow";

          servers = ["tcp://mqtt.isz.wtf:1883"];

          max_undelivered_messages = config.services.telegraf.extraConfig.agent.metric_buffer_limit;

          topics = [
            "homeassistant/sensor/weatherflow2mqtt_ST-00122016/+/config"
            "homeassistant/sensor/weatherflow2mqtt_ST-00122016/+/state"
          ];
          #persistent_session = true;
          #client_id = "telegraf-${config.networking.hostName}";

          data_format = "json";
          json_string_fields = [
            "*"
          ];

          topic_tag = "";
          topic_parsing = [
            {
              topic = "homeassistant/sensor/+/+/state";
              measurement = "_/_/_/_/measurement";
              tags = "_/_/device/observation_type/_";
            }
            {
              topic = "homeassistant/sensor/+/+/config";
              measurement = "_/_/_/_/measurement";
              tags = "_/_/device/field/_";
            }
          ];

          fieldexclude = [
            "wind_direction"
            "pressure_trend"
          ];
        }];
        processors.regex = [
          {
            namepass = ["weatherflow_*"];
            tags = [{
              key = "device";
              pattern = "^weatherflow2mqtt_";
              replacement = "";
            }];
            order = 10;
          }
          {
            namepass = ["weatherflow_config"];
            fieldinclude = [
              "unit_of_measurement"
            ];
            order = 15;
          }
        ];
        processors.starlark = [{
          namepass = ["weatherflow_*"];
          order = 20;
          source = ''
            load("time.star", "time")
            state = dict()
            def tag_key(tags):
              return tuple(tags.items())
            def apply(metric):
              device = metric.tags.get("device")
              name = metric.name.lstrip("weatherflow_")
              if "replay" in metric.fields:
                 # Ignore replayed data
                 return []
              if name == "config":
                 if device not in state:
                   state[device] = dict()
                 state[device][metric.tags["field"]] = dict(metric.fields)
                 return []
              else:
                out = {}
                for field, value in metric.fields.items():
                  tags = state.get(device, {}).get(field, {})
                  key = tag_key(tags)
                  if key not in out:
                    out[key] = Metric(metric.tags["observation_type"])
                    out[key].time = metric.time
                    out[key].tags.update(metric.tags)
                    out[key].tags.pop("observation_type")
                    out[key].tags.update(tags)
                  if type(value) == type("str") and len(value) == 25 and value[10] == "T":
                    t = time.parse_time(value, "2006-01-02T15:04:05Z07:00")
                    value = t.unix
                  out[key].fields[field] = value
                return out.values()
          '';
        }];
      }
    ];
  };
}
