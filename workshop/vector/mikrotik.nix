{ lib, pkgs, ... }:
{
  services.vector = {
    settings = {
      sources.mikrotik = {
        type = "socket";
        mode = "udp";
        address = "0.0.0.0:9001";
        decoding.codec = "vrl";
        # remote-log-format=default is topic,level[,subtopic] message
        # remote-log-format=cef is Nov 22 20:47:18 router.isz.wtf CEF:0|MikroTik|RB4011iGS+5HacQ2HnD|7.20.4 (stable)|44|radvd,debug|Low|dvchost=router.isz.wtf dvc=172.30.97.3 msg=  prefix: xxx\r\n
        # remote-log-format=cef syslog-time-format=iso8601 is 2025-11-22T21:24:35.265-0500 router.isz.wtf CEF:0|MikroTik|RB4011iGS+5HacQ2HnD|7.20.4 (stable)|16|dhcp,debug,packet|Low|dvchost=router.isz.wtf dvc=172.30.97.3 msg=    Router \= 192.168.88.1\r\n
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
          cef, err = parse_cef(.message)
          if err == null {
              ts = parse_timestamp(split(.message, " ") ?? "", "%Y-%m-%dT%H:%M:%S%.3f%:z") ?? .timestamp
              . = {
                  "timestamp": ts,
                  "host": cef.dvchost,
                  "ip": cef.dvc,
                  "topics": cef.name,
                  "message": replace(string!(cef.msg), r'\r\n$', ""),
                  "vendor": cef.deviceVendor,
                  "version": cef.deviceVersion,
                  "product": cef.deviceProduct,
                  "eventClassId": cef.deviceEventClassId,
              }
          } else {
              parts, err = parse_regex(.message, r'^(?P<topics>[^ ]+) (?P<message>.*)$')
              if err == null {
                  .message = parts.message
                  .topics = parts.topics
              }
          }
          .topics = split(.topics, ",") ?? []
          .topics = filter(.topics) -> |_index, value| {
              is_level = get!(LEVELS, [value])
              if is_level == true {
                  .level = value
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
          .name = join!(.topics, ",")
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
        merge_strategies."topics" = "flat_unique";
        merge_strategies."port" = "discard";
      };
      transforms.mikrotik_remap = {
        type = "remap";
        inputs = ["mikrotik_reduce"];
        source = ''
          .source_type = "mikrotik"
          .labels = {}
          .structured_metadata = {}

          ${lib.concatMapStringsSep "\n" (key: ''
            if exists(.${key}) {
              .labels.${key} = .${key}
              del(.${key})
            }
          '') [
            "host"
            "ip"
            "port"
            "source_type"
            "level"
            "topic"
            "name"
          ]}

          ${lib.concatMapStringsSep "\n" (key: ''
            if exists(.${key}) {
              .structured_metadata.${key} = .${key}
              del(.${key})
            }
          '') [
            "vendor"
            "version"
            "product"
            "eventClassId"
          ]}

          del(.timestamp_end)
        '';
      };
    };
  };
  isz.vector.sinks.loki.mikrotik = {
    inputs = ["mikrotik_remap"];
  };
}
