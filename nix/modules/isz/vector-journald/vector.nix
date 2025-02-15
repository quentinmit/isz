{ config, lib, ... }:
{
  config = lib.mkIf config.services.vector.enable {
    isz.vector.journald.services.vector.transforms = [
      {
        type = "remap";
        source = ''
          LEVELS = {
            "ERROR": "error",
            "WARN": "warn",
            "INFO": "info",
            "DEBUG": "debug",
            "TRACE": "trace",
          }
          parts, err = parse_regex(.message, r'(?s)(?P<time>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}Z)\s+(?P<level>\S+)\s+(?P<message>.+)')
          if err == null {
            .structured_metadata.level = get!(LEVELS, [parts.level])
            .message = parts.message
            # TODO: Do something with time?
            # 2025-02-13T09:47:34.068639Z
          }
        '';
      }
    ];
  };
}
