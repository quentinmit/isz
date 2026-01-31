{ config, lib, pkgs, ... }:
let
  cfg = config.programs.alpine;
  confFormat = let
    mkValueString = v:
      if lib.isList v then
        lib.concatMapStringsSep ", " mkValueString v
      else
        lib.generators.mkValueStringDefault {} v;
  in pkgs.formats.keyValue {
    mkKeyValue = lib.generators.mkKeyValueDefault {
      inherit mkValueString;
    } "=";
  };
  confFile = confFormat.generate "pine.conf" cfg.extraConfig;
in {
  options.programs.alpine = with lib; {
    enable = mkEnableOption "Alpine";
    package = mkOption {
      type = types.package;
      default = pkgs.alpine;
    };
    extraConfig = mkOption {
      type = types.attrsOf (types.coercedTo types.str (s: [s]) (types.listOf types.str));
      default = {};
      description = ''
        Settings for .pinerc.

        These settings are applied by passing -P to alpine, which means they
        set default values that may still be overridden by ~/.pinerc.

        Each setting may be a string or a list of strings. If a list of strings
        is supplied, they will be separated with commas. Each Alpine option
        has its own rules for quoting or escaping commas, so if your strings
        contain commas, you should escape them yourself.
      '';
    };
    features = mkOption {
      type = types.attrsOf types.bool;
      default = {};
    };
  };
  config = lib.mkMerge [
    {
      programs.alpine.extraConfig.feature-list =
        lib.mkIf (cfg.features != {})
          (lib.mapAttrsToList
            (k: v: if v then k else "no-${k}")
            cfg.features);
    }
    (lib.mkIf cfg.enable {
      home.packages = [
        cfg.package
        (lib.hiPrio (pkgs.writeShellScriptBin "alpine" ''
          exec ${lib.getExe cfg.package} -P ${confFile}
        ''))
      ];
    })
  ];
}
