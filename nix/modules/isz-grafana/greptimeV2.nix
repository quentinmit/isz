{ config, pkgs, lib, ... }:
let
  inherit
    (import ./lib.nix { inherit config pkgs lib; })
    dashboardFormat
    toProperties;
in {
  options = let
    Query = lib.types.submodule ({ config, ... }: {
      key = "Query";
      options = {
        queryType = lib.mkOption {
          type = lib.types.enum ["table" "logs" "timeseries" "traces"];
          default = "timeseries";
        };
        rawSql = lib.mkOption {
          type = lib.types.str;
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
        panelQuery.spec = {
          query = {
            spec.editorType = "sql";
            spec = {
              inherit (config) queryType rawSql;
            };
          };
        };
      };
    });
  in {
    greptime = lib.mkOption {
      type = lib.types.either Query (lib.types.listOf Query);
      default = [];
    };
  };
  config.spec = let
    queries = lib.imap0 (i: greptime:
      let
        refId = "Greptime${lib.elemAt [ "A" "B" "C" "D" "E" "F" "G" "H" "I" "J" "K" "L" "M" "N" "O" "P" "Q" "R" "S" "T" "U" "V" "W" "X" "Y" "Z" ] i}";
        in {
          panelQuery.spec = greptime.panelQuery.spec // {
            inherit refId;
          };
          override = if greptime.options != null then {
            matcher.id = "byFrameRefID";
            matcher.options = refId;
            properties = toProperties greptime.options;
          } else null;
        }) (lib.toList config.greptime);
  in lib.mkIf (config.greptime != []) {
    vizConfig.group = lib.mkDefault "timeseries";
    data.spec.queryOptions.interval = lib.mkOptionDefault "10s";
    data.spec.queries = map (q: q.panelQuery) queries;
    vizConfig.spec.fieldConfig.overrides = builtins.filter (o: o != null) (map (q: q.override) queries);
  };
}
