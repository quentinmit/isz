{ config, lib, pkgs, ... }:
{
  sops.secrets."vector/loki/oauth_token" = {};
  systemd.services.vector.serviceConfig.LoadCredential = "loki_oauth_token:${config.sops.secrets."vector/loki/oauth_token".path}";
  services.vector = {
    enable = true;
    package = pkgs.unstable.vector;
    journaldAccess = true;
    settings = {
      api.enabled = true;
      secret.systemd.type = "exec";
      secret.systemd.command = [
        (pkgs.writers.writePython3 "vector-secrets" {} ''
          import os
          import os.path
          import json
          import sys

          req = json.load(sys.stdin)
          assert req.get("version") == "1.0"

          out = {}
          for name in req["secrets"]:
              try:
                  data = open(
                      os.path.join(
                          os.environ["CREDENTIALS_DIRECTORY"],
                          name,
                      )
                  ).read()
                  out[name] = {"value": data, "error": None}
              except OSError as e:
                  out[name] = {"value": None, "error": str(e)}
          print(json.dumps(out))
        '')
      ];
      sources.syslog_udp = {
        type = "syslog";
        mode = "udp";
        address = "0.0.0.0:9000";
        # Fields: appname, facility, host, hostname, severity
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
      sinks.console = {
        type = "console";
        inputs = ["syslog_udp"];
        encoding.codec = "json";
        encoding.json.pretty = true;
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
      sources.journald = {
        type = "journald";
        current_boot_only = false;
      };
      transforms.journald_remap = {
        type = "remap";
        inputs = ["journald"];
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
            "0": "fatal", # emerg
            "1": "error", # alert
            "2": "error", # crit
            "3": "error", # err
            "4": "warn", # warning
            "5": "info", # notice
            "6": "info", # info
            "7": "debug", # debug
          }
          .labels = {}
          priority, err = to_syslog_level(to_int(.PRIORITY) ?? -1)
          if err == null {
            .priority = priority
          }
          if exists(.PRIORITY) {
            level = get!(LEVELS, [.PRIORITY])
            if level != null {
              .level = level
            }
          }
          facility, err = to_syslog_facility(to_int(.SYSLOG_FACILITY) ?? -1)
          if err == null {
            .facility = facility
          }
          ${lib.concatMapStringsSep "\n" (key: ''
            if exists(.${key}) {
              .labels.${key} = .${key}
              del(.${key})
            }
          '') [
            "host"
            "source_type"
          ]}
          ${pkgs.unstable.lib.concatMapAttrsStringSep "\n" (out: src: ''
            if exists(.${src}) {
              .labels.${out} = .${src}
            }
          '') {
            service_namespace = "_SYSTEMD_SLICE";
            service_name = "_SYSTEMD_UNIT";
          }}
          del(.source_type)
          del(.host)
          structured_metadata = filter(.) -> |key, _value| {
            !includes(["labels", "message", "timestamp"], key)
          }
          # Work around https://github.com/grafana/loki/issues/16148
          structured_metadata = map_keys(structured_metadata) -> |key| {
            if starts_with(key, "_") {
              "trusted" + key
            } else {
              key
            }
          }
          . = {
            "labels": .labels,
            "message": .message,
            "timestamp": .timestamp,
            "structured_metadata": structured_metadata,
          }
        '';
      };
      sinks.loki_journald = {
        type = "loki";
        inputs = ["journald_remap"];
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
