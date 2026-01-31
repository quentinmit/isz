{ config, lib, pkgs, ... }:
let
  cfg = config.programs.alpine;
  confFormat = let
    mkValueString = v:
      if lib.isList v then
        lib.concatMapStringsSep ", " mkValueString v
      else
        lib.escape [","] (lib.generators.mkValueStringDefault {} v);
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
