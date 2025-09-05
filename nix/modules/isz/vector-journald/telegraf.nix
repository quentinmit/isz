{ config, lib, ... }:
{
  config = lib.mkIf config.services.telegraf.enable {
    isz.vector.journald.services.telegraf.transforms = [
      {
        type = "remap";
        source = ''
          TELEGRAF_LEVELS = {
            "E": "error",
            "W": "warn",
            "I": "info",
            "D": "debug",
          }
          parts, err = parse_regex(.message, r'(?P<time>\S+)\s+(?P<level>.)!\s+(?P<message>(\[(?P<plugin>[^]]+)\]\s+)?.+)')
          if err == null {
            .structured_metadata.level = get!(TELEGRAF_LEVELS, [parts.level])
            if parts.plugin != null {
              .structured_metadata.plugin = parts.plugin
            }
            .message = parts.message
          }
        '';
      }
    ];
  };
}
