{ config, lib, ... }:
{
  config = lib.mkIf config.services.grafana.enable {
    isz.vector.journald.services.grafana.transforms = [
      {
        type = "remap";
        source = ''
          parts, err = parse_logfmt(.message)
          if err == null {
            .structured_metadata.level = parts.level
            del(parts.level)
            # TODO: Do something with parts.t?
            # t=2025-02-15T03:15:18.633412264-05:00
            del(parts.t)
            .message = parts.msg
            del(parts.msg)
            .structured_metadata |= parts
          }
        '';
      }
    ];
  };
}
