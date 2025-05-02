{ lib, pkgs, ... }:
{
  isz.vector.enable = true;
  systemd.services.vector.serviceConfig.RuntimeDirectory = "vector";
  services.vector = {
    settings = {
      sources.syslog_udp = {
        type = "syslog";
        mode = "udp";
        address = "0.0.0.0:9000";
        # Fields: appname, facility, host, hostname, severity
      };
      transforms.syslog_remap = {
        type = "remap";
        inputs = ["syslog_udp"];
        # Sample message:
        #   "source_type": "syslog",
        #   "source_ip": "172.30.97.21",
        #   "host": "meshradio",
        #   "severity": "info",
        #   "timestamp": "2025-04-27T21:14:38Z"
        #   "procid": 3285,
        #   "facility": "authpriv",
        #   "hostname": "meshradio",
        #   "appname": "dropbear",
        #   "message": "Child connection from 172.30.96.104:53240",
        # Valid levels at: https://github.com/grafana/loki/blob/main/pkg/util/constants/levels.go#L15
        # critical
        # fatal
        # error
        # warn
        # info
        # debug
        # trace
        # unknown
        source = ''
          LEVELS = {
            "emergency": "fatal", # emerg
            "alert": "critical", # alert
            "critical": "critical", # crit
            "error": "error", # err
            "warn": "warn", # warning
            "notice": "info", # notice
            "info": "info", # info
            "debug": "debug", # debug
          }
          if exists(.severity) {
            level = get!(LEVELS, [.severity])
            if level != null {
              .level = level
            }
          }
          .labels = {}
          ${lib.concatMapStringsSep "\n" (key: ''
            if exists(.${key}) {
              .labels.${key} = .${key}
              del(.${key})
            }
          '') [
            "host"
            "source_ip"
            "source_type"
          ]}
          ${pkgs.unstable.lib.concatMapAttrsStringSep "\n" (out: src: ''
            if exists(.${src}) {
              .labels.${out} = .${src}
            }
          '') {
            service_name = "appname";
          }}
          structured_metadata = filter(.) -> |key, _value| {
            !includes(["labels", "message", "timestamp"], key)
          }
          . = {
            "labels": .labels,
            "message": .message,
            "timestamp": .timestamp,
            "structured_metadata": structured_metadata,
          }
        '';
      };
      sinks.loki_syslog = {
        type = "loki";
        inputs = ["syslog_remap"];
        endpoint = "https://loki.isz.wtf";
        encoding.codec = "raw_message";
        remove_label_fields = true;
        labels."*" = "{{ labels }}";
        remove_structured_metadata_fields = true;
        structured_metadata."*" = "{{ structured_metadata }}";
        slugify_dynamic_fields = false;
        auth.strategy = "bearer";
        auth.token = "SECRET[systemd.loki_oauth_token]";
      };
      sources.mikrotik = {
        type = "socket";
        mode = "udp";
        address = "0.0.0.0:9001";
        decoding.codec = "vrl";
        # Packet format is topic,level[,subtopic] message
        decoding.vrl.source = ''
          LEVELS = {
              "critical": true,
              "debug": true,
              "error": true,
              "info": true,
              "warning": true,
              "raw": false,
              "packet": false,
          }
          parts, err = parse_regex(.message, r'^(?P<topics>[^ ]+) (?P<message>.*)$')
          if err == null {
              .message = parts.message
              .topics = split(string!(parts.topics), ",")
              .topics = filter(.topics) -> |_index, value| {
                  is_level = get!(LEVELS, [value])
                  if is_level == true {
                      .severity = value
                      false
                  } else if is_level == false {
                      # flags
                      . = set!(., [value], true)
                      false
                  } else {
                      true
                  }
              }
              .topic = .topics[0]
              .subtopic = .topics[1]
          }
          .source_type = "mikrotik"
        '';
      };
      transforms.mikrotik_reduce = {
        type = "reduce";
        inputs = ["mikrotik"];
        starts_when = ''
          !match(string!(.message), r'^\s')
        '';
        # Can't use group_by because it produces out-of-order logs.
        merge_strategies.message = "concat_newline";
        merge_strategies.topics = "flat_unique";
      };
      sinks.loki_mikrotik = {
        type = "loki";
        inputs = ["mikrotik_reduce"];
        endpoint = "https://loki.isz.wtf";
        encoding.codec = "json";
        labels = {
          source_type = "{{ source_type }}";
          host = "{{ host }}";
          topic = "{{ topic }}";
          subtopic = "{{ subtopic }}";
          level = "{{ severity }}";
        };
        auth.strategy = "bearer";
        auth.token = "SECRET[systemd.loki_oauth_token]";
      };

      sources.telegraf_netflow = {
        type = "socket";
        mode = "unix_datagram";
        path = "/run/vector/telegraf_netflow.sock";
        socket_file_mode = 438; # 0666 - TODO: restrict to a group shared with telegraf

        framing.method = "newline_delimited";
        decoding.codec = "json";
      };
      transforms.netflow_format = {
        type = "remap";
        inputs = ["telegraf_netflow"];
        source = ''
          host = .tags.source
          del(.tags.source)
          del(.tags.influxdb_bucket)

          . = {
            "labels": {
              "host": host,
              "source_type": "netflow",
            },
            "message": encode_logfmt!(.fields),
            "timestamp": .timestamp,
            "structured_metadata": .tags,
          }
        '';
      };
      sinks.loki_netflow = {
        type = "loki";
        inputs = [
          "netflow_format"
        ];
        endpoint = "https://loki.isz.wtf";
        encoding.codec = "raw_message";
        remove_label_fields = true;
        labels."*" = "{{ labels }}";
        remove_structured_metadata_fields = true;
        structured_metadata."*" = "{{ structured_metadata }}";
        slugify_dynamic_fields = false;
        auth.strategy = "bearer";
        auth.token = "SECRET[systemd.loki_oauth_token]";
      };
    };
  };
}
