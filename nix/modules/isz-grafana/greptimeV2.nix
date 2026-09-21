{ config, pkgs, lib, ... }:
let
  inherit
    (import ./lib.nix { inherit config pkgs lib; })
    dashboardFormat
    literalExpressionType
    sqlIdentifier
    sqlValue
    sqlFilter
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
        filter = lib.mkOption {
          type = let
            inherit (lib.types) submodule coercedTo nullOr attrsOf listOf oneOf enum str int bool;
          in attrsOf (
            coercedTo str (s: { values = [s]; })
              (coercedTo (listOf str) (s: { values = s; })
               (submodule {
                 key = "Query.filter";
                 options = {
                   op = lib.mkOption {
                     type = enum ["=" "!="];
                     default = "=";
                   };
                   values = lib.mkOption {
                     type = coercedTo str (s: [s]) (listOf (nullOr (oneOf [str int bool literalExpressionType])));
                   };
                 };
               }))
          );
          default = {};
        };
        database = lib.mkOption {
          type = lib.types.str;
        };
        table = lib.mkOption {
          type = lib.types.str;
        };
        tags = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
        };
        fields = lib.mkOption {
          type = lib.types.listOf (lib.types.either lib.types.str literalExpressionType);
        };
        fn = lib.mkOption {
          type = lib.types.enum ["last1" "mean"];
        };
        panelQuery = lib.mkOption {
          type = dashboardFormat.type;
        };
      };
      config = {
        rawSql = let
          tags = lib.concatMapStringsSep ", " sqlIdentifier config.tags;
          filters = ''(${lib.concatStringsSep ") AND (" (["$__timeFilter(greptime_timestamp)"] ++ (lib.mapAttrsToList sqlFilter config.filter))})'';
        in lib.mkDefault (
          if config.fn == "last1" then ''
            SELECT DISTINCT ON (${tags})
              ${lib.concatMapStringsSep ", " sqlIdentifier (config.tags ++ config.fields)}
            FROM
              ${sqlIdentifier config.database}.${sqlIdentifier config.table}
            WHERE
              ${filters}
            ORDER BY ${lib.concatMapStringsSep ", " sqlIdentifier config.tags}, greptime_timestamp DESC
          '' else ''
            SELECT
              ${tags},
              greptime_timestamp,
              ${lib.concatMapStringsSep ", " (x: "${config.fn}(${sqlIdentifier x}) RANGE '$__interval' FILL NULL AS ${sqlIdentifier x}") config.fields},
            FROM
              ${sqlIdentifier config.database}.${sqlIdentifier config.table}
            WHERE
              ${filters}
            ALIGN '$__interval' BY (${tags})
            ORDER BY greptime_timestamp ASC
          ''
        );
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
