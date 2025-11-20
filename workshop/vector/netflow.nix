{ lib, pkgs, ... }:
{
  services.vector = {
    settings = {
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
    };
  };
  isz.vector.sinks.loki.netflow = {
    inputs = [
      "netflow_format"
    ];
  };
}
