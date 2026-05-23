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
      services.udev.packages = [(pkgs.writeTextFile {
        name = "70-local.rules";
        destination = "/etc/udev/rules.d/70-local.rules";
        text = concatMapStringsSep "\n" (
          rule: concatStringsSep ", " (
            lib.mapAttrsToList
              (name: v: "${name}${v.op}${escapeUdev v.value}")
              (lib.mapAttrs (name: v: if isString v then { op = "=="; value = v; } else v) rule)
          )
        ) cfg.rules;
        checkPhase = ''
          ${config.systemd.package}/bin/udevadm verify --resolve-names=late $out/etc/udev/rules.d/70-local.rules
        '';
      })];
    };
}
