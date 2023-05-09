{ config, pkgs, lib, ... }:
with import ./lib.nix { inherit config pkgs lib; };
let
  muninPanel = datasource: g: {
    gridPos = {
      w = 12;
      h = 8;
      x = if g.right then 12 else 0;
    };
    title = g.graph_title;
    type = "timeseries";
    interval = "10s";
    options.tooltip.mode = "multi";
    options.legend = {
      showLegend = true;
      displayMode = "table";
      placement = "bottom";
      calcs = [
        "lastNotNull"
        "min"
        "mean"
        "max"
      ];
      sortBy = "Last *";
      sortDesc = true;
    };
    fieldConfig.defaults = lib.mkMerge [
      {
        unit = g.unit;
      }
      (lib.mkIf g.stacking {
        custom.stacking.mode = "normal";
        custom.fillOpacity = lib.mkDefault 10;
      })
      (lib.mkIf (g.graph_vlabel != null) {
        custom.axisLabel = g.graph_vlabel;
      })
      (lib.mkIf (g.graph_args.lower-limit != null) {
        min = g.graph_args.lower-limit;
      })
      (lib.mkIf (g.graph_args.upper-limit != null) {
        max = g.graph_args.upper-limit;
      })
      (lib.mkIf g.graph_args.logarithmic {
        custom.scaleDistribution.type = "log";
        custom.scaleDistribution.log = lib.mkDefault 10;
      })
      g.defaults
    ];
    fieldConfig.overrides = lib.mapAttrsToList
      (field: options: {
        matcher.id = "byName";
        matcher.options = field;
        properties = lib.mapAttrsToList (id: value: {
          inherit id value;
        }) (toProperties options);
      })
      g.fields;
    inherit datasource;
    targets = let
      filters = lib.mapAttrsToList (field: values:
        ''|> filter(fn: (r) => ${fluxFilter field values})'');
    in lib.imap0 (i: influx: {
      inherit datasource;
      query =
        lib.concatMapStringsSep "\n" (x: ''import ${fluxValue x}'') influx.imports + ''
        from (bucket: v.defaultBucket)
        |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
        ${lib.concatStringsSep "\n" (filters influx.filter)}
        |> filter(fn: (r) => r.host =~ /^''${host:regex}$/)
      '' + (if influx.fn == "derivative" then ''
        |> aggregateWindow(every: v.windowPeriod, fn: last)
        |> derivative(unit: 1s, nonNegative: true)
      '' else ''
        |> aggregateWindow(every: v.windowPeriod, fn: ${influx.fn}, createEmpty: false)
      '') + lib.optionalString influx.pivot ''
        |> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")
        |> drop(columns: ["_start", "_stop"])
      '' + influx.extra;
      refId = lib.elemAt [ "A" "B" "C" "D" "E" "F" "G" "H" "I" "J" "K" "L" "M" "N" "O" "P" "Q" "R" "S" "T" "U" "V" "W" "X" "Y" "Z" ] i;
    }) (lib.toList g.influx);
  } // lib.optionalAttrs (g.repeat != null) {
    repeat = g.repeat;
    repeatDirection = "v";
  } // lib.optionalAttrs (g.graph_info != null) {
    description = g.graph_info;
  } // lib.optionalAttrs (g.fieldOrder != null) {
    transformations = [{
      id = "organize";
      options.indexByName = builtins.listToAttrs (lib.imap0 (i: key: lib.nameValuePair key i) g.fieldOrder);
    }];
  };
in {
  options = with lib; {
    isz.grafana.dashboards = mkOption {
      type = with types; attrsOf (submodule {
        options.munin.graphs = let
          Query = types.submodule {
            options = {
              filter = mkOption {
                type = with types; attrsOf (
                  coercedTo str (s: { values = [s]; })
                    (coercedTo (listOf str) (s: { values = s; })
                      (submodule {
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
                type = types.enum ["derivative" "mean"];
              };
              pivot = mkEnableOption "pivot";
              extra = mkOption {
                type = types.str;
                default = "";
                description = "Extra Flux expressions to append at the end of the query";
              };
            };
          };
          FieldConfig = (pkgs.formats.json {}).type;
          Graph = types.submodule {
            options = {
              graph_title = mkOption {
                type = types.str;
              };
              graph_vlabel = mkOption {
                type = with types; nullOr str;
                default = null;
              };
              graph_info = mkOption {
                type = with types; nullOr str;
                default = null;
              };
              graph_args.lower-limit = mkOption {
                type = with types; nullOr int;
                default = null;
              };
              graph_args.upper-limit = mkOption {
                type = with types; nullOr int;
                default = null;
              };
              graph_args.logarithmic = mkEnableOption "logarithmic scale";
              influx = mkOption {
                type = with types; either Query (listOf Query);
              };
              defaults = mkOption {
                type = FieldConfig;
                default = {};
              };
              fields = mkOption {
                type = types.attrsOf FieldConfig;
                default = {};
              };
              unit = mkOption {
                type = types.str;
                default = "none";
              };
              repeat = mkOption {
                type = with types; nullOr str;
                default = null;
              };
              fieldOrder = mkOption {
                type = with types; nullOr (listOf str);
                default = null;
              };
              stacking = mkEnableOption "stack series";
              right = mkEnableOption "place graph on right";
            };
          };
        in mkOption {
          type = with types; attrsOf (attrsOf Graph);
          default = {};
        };
      });
    };
  };
  config = {
    services.grafana.dashboards = lib.mapAttrs (_: dashboard: let
      datasource = {
        inherit (config.isz.grafana.datasources.${dashboard.defaultDatasourceName}) uid type;
      };
    in {
      panels = let
        panels = lib.concatLists (
          lib.mapAttrsToList
            (category: graphs:
              [{
                title = category;
                type = "row";
                gridPos.h = 1;
                gridPos.w = 24;
              }] ++
              lib.mapAttrsToList (_: g: muninPanel datasource g) graphs
            )
            dashboard.munin.graphs
        );
        sumHeights = lib.foldl' (s: p: s + p.gridPos.h) 0;
      in
        lib.foldl (a: b: a ++ [(b // { gridPos = b.gridPos // { y = if (b.gridPos.x or 0) == 0 then sumHeights a else (lib.last a).gridPos.y; }; })]) [] panels;
    }) config.isz.grafana.dashboards;
  };
}
