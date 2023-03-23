{ lib, pkgs, config, options, ... }:
{
  options = with lib; {
    services.udev = {
      rules = mkOption {
        default = [];
        type = with types; listOf (attrsOf (either str submodule { options = {
          op = mkOption { type = enum [ "==" "!=" "=" "+=" "-=" ":=" ]; };
          value = mkOption { type = str; };
        }; }));
      };
    };
  };
  config = with lib.strings; let
    cfg = config.services.udev;
    escapeUdev = arg: ''"${replaceStrings [''"''] [''\\"''] arg}"'';
    doRule = rule:
      concatStringsSep ", " mapAttrsToList (
        name: value: (value: "${name}${value.op}${escapeUdev value.value}") (if isString value then value else { op = "=="; inherit value; })) rule;
  in
    {
      services.udev.extraRules = concatMapStringsSep "\n" doRule cfg.rules;
    };
}