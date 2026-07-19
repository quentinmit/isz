{ config, lib, ... }:
{
  config = lib.mkIf config.services.grafana.enable {
    isz.vector.journald.services.grafana.transforms = [
      {
        type = "remap";
        source = ''
          message = string(.message) ?? ""
          if starts_with(message, "logger=") {
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
          } else if starts_with(message, "{") {
            parts, err = parse_json(.message)
            if err == null {
              .structured_metadata.level = parts."@level"
              del(parts."@level")
              # TODO: Do something with parts."@timestamp"?
              # 2026-07-18T23:49:10.021418-04:00
              del(parts."@timestamp")
              .message = parts."@message"
              del(parts."@message")
              # TODO: .structured_metadata |= parts
            }
          }
        '';
      }
    ];
  };
}
