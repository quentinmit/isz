{ config, options, pkgs, channels, lib, ... }:
with import ./lib.nix { inherit config pkgs lib; };
let
  cfg = config.isz.grafana;
  inherit (config.services.grafana) kind;
in {
  options = with lib; {
    isz.grafana.dashboardsV2 = mkOption {
      default = {};
      type = with types; attrsOf (submodule ({ config, ... }: {
        options = {
          title = mkOption {
            type = types.str;
          };
          tags = mkOption {
            type = types.listOf types.str;
            default = [];
          };
          defaultDatasourceName = mkOption {
            type = types.str;
          };
          variables = let
            variableOpts = { name, config, ... }: {
              options = {
                tag = mkOption {
                  type = types.str;
                };
                predicate = mkOption {
                  type = types.str;
                };
                extra = mkOption {
                  type = types.attrsOf dashboardFormat.type;
                  default = {};
                };
                query = mkOption {
                  type = types.str;
                };
              };
              config = {
                tag = mkDefault name;
                query = mkDefault ''
                  import "influxdata/influxdb/schema"

                  schema.tagValues(
                    bucket: v.defaultBucket,
                    tag: ${fluxValue config.tag},
                    predicate: (r) => ${config.predicate},
                    start: v.timeRangeStart,
                    stop: v.timeRangeStop
                  )
                '';
              };
            };
          in mkOption {
            type = with types; attrsOf (submodule variableOpts);
            default = {};
          };
          links = mkOption {
            type = types.listOf dashboardFormat.type;
            default = [];
          };
          annotations = mkOption {
            inherit ((options.services.grafana.dashboardsV2.type.getSubOptions []).spec.annotations) type;
            default = [];
          };
          panels = mkOption {
            type = types.attrsOf (types.submoduleWith {
              modules = [ ./panelV2.nix ];
              shorthandOnlyDefinesConfig = true;
              specialArgs = let
                panelNames = builtins.attrNames config.panels;
                panelIndexes = lib.listToAttrs (lib.imap1 (i: n: lib.nameValuePair n i) panelNames);
              in {
                inherit (cfg) datasources;
                inherit (config) defaultDatasourceName;
                inherit pkgs panelIndexes;
                extraInfluxFilter = {};
              };
            });
            default = [];
          };
          layout = mkOption {
            inherit ((kind.Dashboard.getSubOptions []).spec.layout) type;
            default = {
              kind = "AutoGridLayout";
              spec.items = lib.mapAttrsToList (name: _: {
                spec.element = {
                  inherit name;
                };
              }) config.panels;
            };
          };
        };
      }));
    };
  };
  config = {
    services.grafana.dashboardsV2 = lib.mapAttrs (_: dashboard: let
      datasource = {
        inherit (cfg.datasources.${dashboard.defaultDatasourceName}) uid type;
      };
      in {
        spec = {
          inherit (dashboard) title tags links layout;
          elements = lib.mapAttrs (_: p: {
            kind = "Panel";
            inherit (p) spec;
          }) dashboard.panels;
          variables = lib.mapAttrsToList (name: args: {
            kind = "QueryVariable";
            spec = lib.recursiveUpdate rec {
              name = args.tag;
              query = {
                datasource.name = dashboard.defaultDatasourceName;
                group = "influxdb";
                spec = {
                  inherit (args) query;
                };
              };
              includeAll = true;
              label = name;
            } args.extra;
          }) dashboard.variables;
          annotations = (options.services.grafana.dashboardsV2.type.getSubOptions []).spec.annotations.default ++ dashboard.annotations;
        };
      }) cfg.dashboardsV2;
  };
}
