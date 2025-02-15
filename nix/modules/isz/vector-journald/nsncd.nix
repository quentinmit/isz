{ config, lib, ... }:
{
  config = lib.mkIf (config.services.nscd.enable && config.services.nscd.enableNsncd) {
    isz.vector.journald.services.nscd.transforms = [
      {
        type = "remap";
        source = ''
          # https://docs.rs/slog/latest/src/slog/lib.rs.html#2085
          LEVELS = {
            "CRIT": "critical",
            "ERRO": "error",
            "WARN": "warn",
            "INFO": "info",
            "DEBG": "debug",
            "TRCE": "trace",
          }
          # Feb 15 17:57:33.002 ERRO timed out waiting for an available worker, thread: accept
          parts, err = parse_regex(.message, r'(?s)(?P<time>\S+ \d{1,2} \d{2}:\d{2}:\d{2}\.\d{3})\s+(?P<level>\S+)\s+(?P<message>.+)')
          if err == null {
            .structured_metadata.level = get!(LEVELS, [parts.level])
            .message = parts.message
            # TODO: Do something with time?
          }
        '';
      }
    ];
  };
}
