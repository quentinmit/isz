{ config, pkgs, lib
, name
, datasources
, defaultDatasourceName
, extraInfluxFilter ? {}
, ... }:
with import ./lib.nix { inherit config pkgs lib; };
with import ../grafana/types.nix { inherit pkgs lib; };
let
  queryBase = {
    datasource.name = lib.mkDefault datasources.${config.datasourceName}.uid;
    group = lib.mkDefault datasources.${config.datasourceName}.type;
  };
in {
  config.spec = let
    g = config;
  in lib.mkMerge [
    {
      vizConfig.spec.fieldConfig.overrides = lib.mapAttrsToList
        (field: options: {
          matcher.id = if lib.hasPrefix "/" field then "byRegexp" else "byName";
          matcher.options = field;
          properties = toProperties options;
        })
        g.fields;
    }
    (lib.mkIf (g.fieldOrder != null) {
      data.spec.transformations = [{
        group = "organize";
        spec.options.indexByName = builtins.listToAttrs (lib.imap0 (i: key: lib.nameValuePair key i) g.fieldOrder);
      }];
    })
  ];
  imports = [
    ./influxV2.nix
  ];
  options = with lib; let
    FieldConfig = (pkgs.formats.json {}).type;
  in {
    fields = mkOption {
      type = types.attrsOf FieldConfig;
      default = {};
    };
    fieldOrder = mkOption {
      type = with types; nullOr (listOf str);
      default = null;
    };
    datasourceName = mkOption {
      type = types.str;
      default = defaultDatasourceName;
    };
    spec = mkOption {
      type = types.submodule ({ config, ... }: {
        freeformType = dashboardFormat.type;
        options = {
          data.spec.queries = mkOption {
            default = [];
            type = types.listOf (types.submodule {
              freeformType = dashboardFormat.type;
              config.spec.query = queryBase;
            });
          };
        };
      });
    };
  };
}
