{ lib, pkgs, config, options, ... }:
{
  options = with lib; {
    services.udev.rules = mkOption {
      default = [];
      type = with types; listOf (
        attrsOf (
          either str (submodule {
            options = {
              op = mkOption { type = enum [ "==" "!=" "=" "+=" "-=" ":=" ]; };
              value = mkOption { type = str; };
            };
          })
        )
      );
    };
  };
  config = with lib.strings; let
    cfg = config.services.udev;
    escapeUdev = arg: ''"${replaceStrings [''"''] [''\\"''] arg}"'';
  in
    lib.mkIf (cfg.rules != []) {
      services.udev.extraRules = concatMapStringsSep "\n" (
        rule: concatStringsSep ", " (
          lib.mapAttrsToList
            (name: v: "${name}${v.op}${escapeUdev v.value}")
            (lib.mapAttrs (name: v: if isString v then { op = "=="; value = v; } else v) rule)
        )
      ) cfg.rules;
    };
}
