{ config, options, pkgs, lib, ... }:
with import ./lib.nix { inherit config pkgs lib; };
let
  cfg = config.isz.grafana;
  dashboardType = options.services.grafana.dashboards.type.nestedTypes.elemType;
in {
  imports = [
    ./munin.nix
    ../grafana
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
      #type = options.services.grafana.provision.datasources.settings.datasources.type;
    };
    isz.grafana.dashboards = mkOption {
      default = {};
      type = with types; attrsOf (submodule {
        options = {
          uid = mkOption {
            type = types.str;
          };
          title = mkOption {
            type = types.str;
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
              };
              config = {
                tag = mkDefault name;
              };
            };
          in mkOption {
            type = with types; attrsOf (submodule variableOpts);
            default = {};
          };
          panels = mkOption {
            type = types.listOf (dashboardType.getSubOptions []).panels.type;
            default = [];
          };
        };
      });
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
        inherit (dashboard) uid title panels;
        templating.list = lib.mapAttrsToList (name: args: lib.recursiveUpdate rec {
          inherit (args) tag;
          query = ''
            import "influxdata/influxdb/schema"

            schema.tagValues(
              bucket: v.defaultBucket,
              tag: ${fluxValue tag},
              predicate: (r) => ${args.predicate},
              start: v.timeRangeStart,
              stop: v.timeRangeStop
            )
          '';
          definition = query;
          inherit datasource;
          includeAll = true;
          inherit name;
          type = "query";
        } args.extra) dashboard.variables;
      }) cfg.dashboards;
  };
}
