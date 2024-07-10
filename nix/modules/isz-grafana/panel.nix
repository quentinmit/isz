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
          properties = toProperties options;
        })
        g.fields;
    }
    (lib.mkIf (g.influx != []) (let
      queries = lib.imap0 (i: influx:
        let
          refId = lib.elemAt [ "A" "B" "C" "D" "E" "F" "G" "H" "I" "J" "K" "L" "M" "N" "O" "P" "Q" "R" "S" "T" "U" "V" "W" "X" "Y" "Z" ] i;
        in {
          target = {
            inherit datasource refId;
            inherit (influx) query;
          };
          override = if influx.options != null then {
            matcher.id = "byFrameRefID";
            matcher.options = refId;
            properties = toProperties influx.options;
          } else null;
        }) (lib.toList g.influx);
    in {
      type = lib.mkDefault "timeseries";
      interval = lib.mkDefault "10s";
      inherit datasource;
      targets = map (q: q.target) queries;
      fieldConfig.overrides = builtins.filter (o: o != null) (map (q: q.override) queries);
    }))
    (lib.mkIf (g.fieldOrder != null) {
      transformations = [{
        id = "organize";
        options.indexByName = builtins.listToAttrs (lib.imap0 (i: key: lib.nameValuePair key i) g.fieldOrder);
      }];
    })
  ];
  options = with lib; let
    Query = types.submodule ({ config, ... }:
      let
        agg = fn:
            if fn == null then ""
          else if fn == "last1" then ''
            |> last()
          '' else if fn == "count1" then ''
            |> count()
          '' else if fn == "derivative" then ''
            |> window(every: v.windowPeriod)
            |> last()
            |> window(every: inf)
            |> derivative(unit: 1s, nonNegative: true)
          '' else ''
            |> aggregateWindow(every: v.windowPeriod, fn: ${fn}, createEmpty: ${fluxValue config.createEmpty})
          '';
        filters = lib.mapAttrsToList (field: values:
          ''|> filter(fn: (r) => ${fluxFilter field values})'');
      in {
      key = "Query";
      options = {
        bucket = mkOption {
          type = with types; nullOr str;
          default = null;
          description = "Bucket name (or null for default)";
        };
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
          type = types.nullOr (types.enum ["derivative" "mean" "min" "max" "last" "last1"]);
        };
        createEmpty = mkOption {
          type = types.bool;
          default = false;
        };
        groupBy = mkOption {
          default = [];
          type = types.coercedTo types.attrs (x: [x]) (types.listOf (types.submodule ({ config, ... }: {
            options = {
              fn = mkOption {
                type = types.enum ["derivative" "sum" "mean" "max" "min" "count" "last" "last1" "count1"];
                default = "sum";
              };
              fields = mkOption {
                type = types.listOf types.str;
                default = [];
              };
              expr = mkOption {
                type = types.str;
              };
            };
            config = {
              expr = lib.mkDefault (''
                |> group(columns: ${fluxValue (config.fields ++ ["_measurement" "_field" "_start" "_stop"])})
              '' + (agg config.fn));
            };
          })));
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
        options = mkOption {
          type = types.nullOr dashboardFormat.type;
          default = null;
          description = "Option overrides for the results of this query";
        };
      };
      config = {
        query = lib.mkDefault (
          lib.concatMapStrings (x: ''import ${fluxValue x}'' + "\n") config.imports + ''
            from (bucket: ${if config.bucket != null then (fluxValue config.bucket) else "v.defaultBucket"})
            |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
            ${lib.concatStringsSep "\n" (filters (extraInfluxFilter // config.filter))}
          '' + (agg config.fn) + lib.concatMapStrings (g: g.expr) config.groupBy + lib.optionalString config.pivot ''
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
