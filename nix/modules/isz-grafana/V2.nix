{ config, options, pkgs, channels, lib, ... }:
with import ./lib.nix { inherit config pkgs lib; };
let
  cfg = config.isz.grafana;
  inherit (config.services.grafana) kind;
in {
  options = with lib; {
    isz.grafana.dashboardsV2 = mkOption {
      default = {};
      type = with types; attrsOf (submodule ({ config, ... }: let
        inherit (config) defaultDatasourceName;
      in {
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
                influx = mkOption {
                  type = types.nullOr (types.submodule ({ config, ... }: {
                    options = {
                      tag = mkOption {
                        type = types.str;
                        default = name;
                      };
                      predicate = mkOption {
                        type = types.str;
                      };
                      query = mkOption {
                        type = types.str;
                      };
                    };
                    config = {
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
                  }));
                };
              };
              config = {
                spec.name = lib.mkDefault name;
                spec.query = lib.mkIf (config.influx != null) {
                  datasource.name = lib.mkDefault defaultDatasourceName;
                  group = "influxdb";
                  spec = {
                    inherit (config.influx) query;
                  };
                };
                spec.includeAll = lib.mkDefault true;
                spec.label = lib.mkDefault name;
              };
            };
          in mkOption {
            type = with types; attrsOf (lib.types.mergeTypes kind.QueryVariable (submodule variableOpts));
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
          spec = mkOption {
            type = types.submodule {
              options = (kind.Dashboard.getSubOptions []).spec;
            };
            default = {};
          };
        };
        config.spec = {
          inherit (config) title tags links layout;
          elements = lib.mapAttrs (_: p: {
            kind = "Panel";
            inherit (p) spec;
          }) config.panels;
          variables = lib.mapAttrsToList (name: args: {
            inherit (args) kind spec;
          }) config.variables;
          annotations = (options.services.grafana.dashboardsV2.type.getSubOptions []).spec.annotations.default ++ config.annotations;
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
        inherit (dashboard) spec;
      }) cfg.dashboardsV2;
  };
}
