{ config, pkgs, lib, ... }:
let
  inherit
    (import ./lib.nix { inherit config pkgs lib; })
    dashboardFormat
    toProperties;
  panelConfig = config;
in {
  options = let
    Query = lib.types.submodule ({ config, ... }: {
      key = "Query";
      options = {
        expr = lib.mkOption {
          type = lib.types.str;
        };
        range = lib.mkOption {
          type = lib.types.bool;
          default = panelConfig.spec.vizConfig.group == "timeseries";
        };
        instant = lib.mkOption {
          type = lib.types.bool;
          default = panelConfig.spec.vizConfig.group != "timeseries";
        };
        legendFormat = lib.mkOption {
          type = lib.types.str;
          default = "__auto";
        };
        format = lib.mkOption {
          type = lib.types.enum ["time_series" "table" "heatmap"];
          default = if panelConfig.spec.vizConfig.group == "table" then "table" else "time_series";
        };
        options = lib.mkOption {
          type = lib.types.nullOr dashboardFormat.type;
          default = null;
          description = "Option overrides for the results of this query";
        };
        panelQuery = lib.mkOption {
          type = dashboardFormat.type;
        };
      };
      config = {
        panelQuery.spec.query = {
          group = "prometheus";
          spec = {
            inherit (config) expr range instant legendFormat format;
            editorMode = "code";
            exemplar = false;
          };
        };
      };
    });
  in {
    prometheus = lib.mkOption {
      type = lib.types.either Query (lib.types.listOf Query);
      default = [];
    };
  };
  config.spec = let
    queries = lib.imap0 (i: prometheus:
      let
        refId = "Prometheus${lib.elemAt [ "A" "B" "C" "D" "E" "F" "G" "H" "I" "J" "K" "L" "M" "N" "O" "P" "Q" "R" "S" "T" "U" "V" "W" "X" "Y" "Z" ] i}";
        in {
          panelQuery.spec = prometheus.panelQuery.spec // {
            inherit refId;
          };
          override = if prometheus.options != null then {
            matcher.id = "byFrameRefID";
            matcher.options = refId;
            properties = toProperties prometheus.options;
          } else null;
        }) (lib.toList config.prometheus);
  in lib.mkIf (config.prometheus != []) {
    vizConfig.group = lib.mkDefault "timeseries";
    data.spec.queryOptions.interval = lib.mkOptionDefault "10s";
    data.spec.queries = map (q: q.panelQuery) queries;
    vizConfig.spec.fieldConfig.overrides = builtins.filter (o: o != null) (map (q: q.override) queries);
  };
}
