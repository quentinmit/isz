{ config, pkgs, lib, ... }:
with import ./lib.nix { inherit config pkgs lib; };
let
  inherit (config.isz.grafana) datasources;
in {
  options = with lib; {
    isz.grafana.dashboards = mkOption {
      type = with types; attrsOf (submodule ({ config, ... }: let
        dashboard = config;
      in {
        options.munin.graphs = let
          Graph = types.submoduleWith {
            modules = [
              ./panel.nix
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
                config.panel = let g = config; in {
                  gridPos = {
                    w = 12;
                    h = 8;
                    x = if g.right then 12 else 0;
                  };
                  title = g.graph_title;
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
                  repeat = lib.mkIf (g.repeat != null) g.repeat;
                  repeatDirection = lib.mkIf (g.repeat != null) "v";
                  description = lib.mkIf (g.graph_info != null) g.graph_info;
                };
              })
            ];
            specialArgs = {
              datasource = {
                inherit (datasources.${dashboard.defaultDatasourceName}) uid type;
              };
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
        config.panels = let
          panels = lib.concatLists (
            lib.mapAttrsToList
              (category: graphs:
                [{
                  panel = {
                    title = category;
                    type = "row";
                    gridPos.h = 1;
                    gridPos.w = 24;
                  };
                }] ++
                lib.mapAttrsToList (_: g: { inherit (g) panel; }) graphs
              )
              dashboard.munin.graphs
          );
          sumHeights = lib.foldl' (s: p: s + p.panel.gridPos.h) 0;
        in
        lib.foldl (a: b: a ++ [(lib.recursiveUpdate b {
          panel.gridPos = b.panel.gridPos // {
            y = if (b.panel.gridPos.x or 0) == 0 then sumHeights a else (lib.last a).panel.gridPos.y;
          };
        })]) [] panels;
      }));
    };
  };
}
