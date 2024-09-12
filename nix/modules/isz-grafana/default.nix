{ config, options, pkgs, channels, lib, ... }:
with import ./lib.nix { inherit config pkgs lib; };
let
  cfg = config.isz.grafana;
in {
  imports = [
    ./munin.nix
    "${channels.unstable}/nixos/modules/services/monitoring/grafana.nix"
  ];
  disabledModules = [
    "services/monitoring/grafana.nix"
  ];
  options = with lib;
    let
      datasourceType = ((options.services.grafana.provision.datasources.type.getSubOptions []).settings.type.getSubOptions []).datasources.type.nestedTypes.elemType;
    in {
    isz.grafana.datasources = mkOption {
      type = types.attrsOf (types.submodule (datasourceType.getSubModules ++ [(
        { name, config, ... }: {
          config = {
            name = mkDefault name;
          };
        }
      )]));
      default = {};
    };
    isz.grafana.dashboards = mkOption {
      default = {};
      type = with types; attrsOf (submodule ({ config, ... }: {
        options = {
          uid = mkOption {
            type = types.str;
          };
          title = mkOption {
            type = types.str;
          };
          tags = mkOption {
            type = types.listOf types.str;
            default = [];
          };
          graphTooltip = mkOption {
            type = types.enum [0 1 2];
            default = 0;
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
            type = (options.services.grafana.dashboards.type.getSubOptions []).annotations.list.type;
            default = [];
          };
          panels = mkOption {
            type = types.listOf (types.submoduleWith {
              modules = [ ./panel.nix ];
              shorthandOnlyDefinesConfig = true;
              specialArgs = {
                inherit (cfg) datasources;
                inherit (config) defaultDatasourceName;
                inherit pkgs;
                extraInfluxFilter = {};
              };
            });
            default = [];
          };
        };
      }));
    };
  };
  config = {
    services.grafana.provision.enable = lib.mkIf (cfg.datasources != {} || cfg.dashboards != {}) true;
    services.grafana.provision.datasources.settings.datasources = lib.mapAttrsToList (name: args: { inherit name; } // args) cfg.datasources;
    services.grafana.dashboards = lib.mapAttrs (_: dashboard: let
      datasource = {
        inherit (cfg.datasources.${dashboard.defaultDatasourceName}) uid type;
      };
      in {
        inherit (dashboard) uid title tags links graphTooltip;
        panels = map (p: (if p.panel.targets != [] then {inherit (lib.elemAt p.panel.targets 0) datasource; } else {}) // p.panel) dashboard.panels;
        templating.list = lib.mapAttrsToList (name: args: lib.recursiveUpdate rec {
          inherit (args) tag query;
          definition = query;
          inherit datasource;
          includeAll = true;
          inherit name;
          type = "query";
        } args.extra) dashboard.variables;
        annotations.list = (options.services.grafana.dashboards.type.getSubOptions []).annotations.list.default ++ dashboard.annotations;
      }) cfg.dashboards;
  };
}
