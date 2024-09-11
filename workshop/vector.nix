{ config, lib, pkgs, ... }:
{
  services.vector = {
    enable = true;
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
          . |= parse_regex!(.message, r'^(?P<topic>[^, ]+),(?P<severity>[^, ]+)(?:,(?P<subtopic>[^, ]+))? (?P<message>.*)$')
          .source_type = "mikrotik"
        '';
      };
      sinks.console = {
        type = "console";
        inputs = ["syslog_udp"];
        encoding.codec = "json";
        encoding.json.pretty = true;
      };
      sinks.loki = {
        type = "loki";
        inputs = ["mikrotik"];
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
