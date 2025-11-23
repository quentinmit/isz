{ lib, ... }:
{
  services.vector.settings = {
    sources.http_client_hitron = {
      type = "http_client";
      endpoint = "https://192.168.100.1/data/status_log.asp";
      tls.verify_certificate = false;
      scrape_interval_secs = 60;
      decoding.codec = "json";
    };
    transforms.hitron_parse = {
      type = "remap";
      inputs = ["http_client_hitron"];
      source = ''
        # Sample log entry:
        #  {
        #    "index": 2,
        #    "time": "11/20/25 11:33:43",
        #    "type": "84020200",
        #    "priority": "warning",
        #    "event": "Lost MDD Timeout;CM-MAC=xx:xx:xx:xx:xx:xx;CMTS-MAC=xx:xx:xx:xx:xx:xx;CM-QOS=1.1;CM-VER=3.1;"
        #  },

        labels = {}
        structured_metadata = {}

        ts = parse_timestamp(.time, "%m/%d/%y %H:%M:%S", "America/New_York") ?? .timestamp

        structured_metadata.type = .type;

        LEVELS = {
          "critical": "critical",
          "warning": "warn",
          "notice": "notice",
        }
        if exists(.priority) {
          level = get!(LEVELS, [.priority])
          if level != null {
            structured_metadata.level = level
          }
        }

        rest = []
        for_each(split!(.event, ";")) -> |_index, part| {
          parsed, err = parse_key_value(part, key_value_delimiter: "=", field_delimiter: ";",whitespace: "strict", accept_standalone_key: false)
          if err == null && _index > 0 {
            structured_metadata = merge(structured_metadata, parsed)
          } else {
            rest = append(rest, [part])
          }
        }
        message = join!(rest, ";")

        labels.host = "192.168.100.1"
        labels.source_type = "hitron"

        . = {
          "labels": labels,
          "message": message,
          "timestamp": ts,
          "structured_metadata": structured_metadata,
        }
      '';
    };
    transforms.hitron_dedupe = {
      type = "dedupe";
      inputs = ["hitron_parse"];
    };
  };
  isz.vector.sinks.loki.hitron = {
    inputs = ["hitron_dedupe"];
  };
}
