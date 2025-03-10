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
        inputs = [
          "syslog_udp"
        ];
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
