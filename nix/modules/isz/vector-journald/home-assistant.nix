{ config, lib, ... }:
{
  config = lib.mkIf config.services.home-assistant.enable {
    isz.vector.journald.services.home-assistant.transforms = [
      {
        type = "reduce";
        expire_after_ms = 1000;
        starts_when = ''
          match(string!(.message), r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}')
        '';
        merge_strategies.message = "concat_newline";
      }
      {
        type = "remap";
        source = ''
          LEVELS = {
            "CRITICAL": "critical",
            "ERROR": "error",
            "WARNING": "warn",
            "INFO": "info",
            "DEBUG": "debug",
          }
          parts, err = parse_regex(.message, r'(?s)(?P<time>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3})\s+(?P<level>\S+)\s+(?P<message>.+)')
          if err == null {
            .structured_metadata.level = get!(LEVELS, [parts.level])
            .message = parts.message
            # TODO: Do something with time?
            # 2025-02-13 03:50:01.083
          }
        '';
      }
    ];
  };
}
