{ config, lib, ... }:
{
  config = lib.mkIf config.services.loki.enable {
    isz.vector.journald.services.loki.transforms = [
      {
        type = "remap";
        source = ''
          parts, err = parse_logfmt(.message)
          if err == null {
            .structured_metadata.level = parts.level[0] || parts.level
            del(parts.level)
            # TODO: Do something with parts.ts?
            # ts=2025-02-15T07:29:14.030104886Z
            # ts=2025-02-15T07:52:19.3463819Z
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
