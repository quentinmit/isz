{ config, pkgs, lib
, datasource
, extraInfluxFilter ? {}
, ... }:
with import ./lib.nix { inherit config pkgs lib; };
with import ../grafana/types.nix { inherit pkgs lib; };
{
  config.panel = let
    g = config;
  in lib.mkMerge [
    {
      fieldConfig.overrides = lib.mapAttrsToList
        (field: options: {
          matcher.id = if lib.hasPrefix "/" field then "byRegexp" else "byName";
          matcher.options = field;
          properties = lib.mapAttrsToList (id: value: {
            inherit id value;
          }) (toProperties options);
        })
        g.fields;
    }
    (lib.mkIf (g.influx != []) {
      type = lib.mkDefault "timeseries";
      interval = lib.mkDefault "10s";
      inherit datasource;
      targets = lib.imap0 (i: influx: {
        inherit datasource;
        inherit (influx) query;
        refId = lib.elemAt [ "A" "B" "C" "D" "E" "F" "G" "H" "I" "J" "K" "L" "M" "N" "O" "P" "Q" "R" "S" "T" "U" "V" "W" "X" "Y" "Z" ] i;
      }) (lib.toList g.influx);
    })
    (lib.mkIf (g.fieldOrder != null) {
      transformations = [{
        id = "organize";
        options.indexByName = builtins.listToAttrs (lib.imap0 (i: key: lib.nameValuePair key i) g.fieldOrder);
      }];
    })
  ];
  options = with lib; let
    Query = types.submodule ({ config, ... }: {
      key = "Query";
      options = {
        filter = mkOption {
          type = with types; attrsOf (
            coercedTo str (s: { values = [s]; })
              (coercedTo (listOf str) (s: { values = s; })
                (submodule {
                  key = "Query.filter";
                  options = {
                    op = mkOption {
                      type = types.enum ["==" "!=" "=~" "!~"];
                      default = "==";
                    };
                    values = mkOption {
                      type = with types; coercedTo str (s: [s]) (listOf str);
                    };
                  };
                }))
          );
        };
        imports = mkOption {
          type = with types; listOf str;
          default = [];
        };
        fn = mkOption {
          type = types.nullOr (types.enum ["derivative" "mean" "last1"]);
        };
        createEmpty = mkOption {
          type = types.bool;
          default = false;
        };
        pivot = mkEnableOption "pivot";
        extra = mkOption {
          type = types.str;
          default = "";
          description = "Extra Flux expressions to append at the end of the query";
        };
        query = mkOption {
          type = types.str;
        };
      };
      config = {
        query = let
          filters = lib.mapAttrsToList (field: values:
            ''|> filter(fn: (r) => ${fluxFilter field values})'');
        in lib.mkDefault (
          lib.concatMapStrings (x: ''import ${fluxValue x}'' + "\n") config.imports + ''
            from (bucket: v.defaultBucket)
            |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
            ${lib.concatStringsSep "\n" (filters (extraInfluxFilter // config.filter))}
          '' + (
            if config.fn == null then ""
            else if config.fn == "last1" then ''
              |> last()
            '' else if config.fn == "derivative" then ''
              |> aggregateWindow(every: v.windowPeriod, fn: last)
              |> derivative(unit: 1s, nonNegative: true)
            '' else ''
              |> aggregateWindow(every: v.windowPeriod, fn: ${config.fn}, createEmpty: ${fluxValue config.createEmpty})
            ''
          ) + lib.optionalString config.pivot ''
            |> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")
            |> drop(columns: ["_start", "_stop"])
          '' + config.extra
        );
      };
    });
    FieldConfig = (pkgs.formats.json {}).type;
  in {
    influx = mkOption {
      type = with types; either Query (listOf Query);
      default = [];
    };
    fields = mkOption {
      type = types.attrsOf FieldConfig;
      default = {};
    };
    fieldOrder = mkOption {
      type = with types; nullOr (listOf str);
      default = null;
    };
    panel = mkOption {
      inherit (dashboardFormat) type;
    };
  };
}
