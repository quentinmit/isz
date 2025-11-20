{ lib, pkgs, ... }:
{
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
    };
  };
  isz.vector.sinks.loki.syslog = {
    inputs = ["syslog_remap"];
  };
}
