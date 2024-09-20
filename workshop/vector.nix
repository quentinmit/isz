{ config, lib, pkgs, ... }:
{
  sops.secrets."vector/loki/oauth_token" = {};
  systemd.services.vector.serviceConfig.LoadCredential = "loki_oauth_token:${config.sops.secrets."vector/loki/oauth_token".path}";
  services.vector = {
    enable = true;
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
      sinks.loki = {
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
    };
  };
}
