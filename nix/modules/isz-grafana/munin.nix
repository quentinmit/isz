{ config, pkgs, lib, ... }:
with import ./lib.nix { inherit config pkgs lib; };
let
  inherit (config.isz.grafana) datasources;
in {
  options = with lib; {
    isz.grafana.dashboardsV2 = mkOption {
      type = with types; attrsOf (submodule ({ config, ... }: let
        dashboard = config;
      in {
        options.munin.graphs = let
          Graph = types.submoduleWith {
            modules = [
              ./panelV2.nix
              ({ config, ... }: {
                key = "munin-panel";
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
                  unit = mkOption {
                    type = types.str;
                    default = "none";
                  };
                  repeat = mkOption {
                    type = with types; nullOr str;
                    default = null;
                  };
                  stacking = mkEnableOption "stack series";
                  right = mkEnableOption "place graph on right";
                };
                config = let g = config; in {
                  # TODO: right
                  spec.title = g.graph_title;
                  spec.vizConfig.spec.options.tooltip.mode = "multi";
                  spec.vizConfig.spec.options.legend = {
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
                  spec.vizConfig.spec.fieldConfig.defaults = lib.mkMerge [
                    {
                      inherit (g) unit;
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
                  ];
                  spec.description = lib.mkIf (g.graph_info != null) g.graph_info;
                };
              })
            ];
            specialArgs = {
              inherit datasources;
              inherit (dashboard) defaultDatasourceName;
              inherit pkgs;
              extraInfluxFilter.host = {
                op = "=~";
                values = ["^\${host:regex}$"];
              };
            };
          };
        in mkOption {
          type = with types; attrsOf (attrsOf Graph);
          default = {};
        };
        config.layout = lib.mkIf (dashboard.munin.graphs != {}) {
          kind = "RowsLayout";
          spec.rows = lib.mapAttrsToList (category: graphs: {
            spec.title = category;
            spec.layout.kind = "AutoGridLayout";
            spec.layout.spec.columnWidthMode = "wide";
            spec.layout.spec.items = lib.mapAttrsToList (name: g: {
              spec.element.name = "${category}.${name}";
              spec.repeat = lib.mkIf (g.repeat != null) {
                mode = "variable";
                value = g.repeat;
              };
            }) graphs;
          }) dashboard.munin.graphs;
        };
        config.panels = lib.concatMapAttrs (category: graphs: lib.mapAttrs' (name: g: lib.nameValuePair "${category}.${name}" {
          inherit (g) spec;
        }) graphs) dashboard.munin.graphs;
      }));
    };
  };
}
