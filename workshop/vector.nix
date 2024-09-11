{ config, lib, pkgs, ... }:
{
  services.vector = {
    enable = true;
    settings = {
      api.enabled = true;
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
          . |= parse_regex!(.message, r'^(?P<topic>[^, ]+),(?P<severity>[^, ]+)(?:,(?P<subtopic>[^, ]+))? (?P<message>.*)$')
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
          source_type = "mikrotik";
          host = "{{ host }}";
          topic = "{{ topic }}";
          subtopic = "{{ subtopic }}";
          level = "{{ severity }}";
        };
      };
    };
  };
}
