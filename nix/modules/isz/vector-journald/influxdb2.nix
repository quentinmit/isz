{ config, lib, ... }:
{
  config = lib.mkIf config.services.influxdb2.enable {
    isz.vector.journald.services.influxdb2.transforms = [
      {
        type = "remap";
        source = ''
          parts, err = parse_logfmt(.message)
          if err == null {
            .structured_metadata.level = parts.lvl
            del(parts.lvl)
            # TODO: Do something with parts.ts?
            # ts=2025-02-15T07:51:53.466102Z
            del(parts.ts)
            .message = parts.msg
            del(parts.msg)
            .structured_metadata |= parts
          }
        '';
      }
    ];
  };
}
