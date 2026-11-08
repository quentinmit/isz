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
    expressionType = lib.types.submodule ({ config, ... }: {
      options = {
        expression = lib.mkOption {
          type = lib.types.str;
          default = sqlIdentifier config.name;
        };
        name = lib.mkOption {
          type = lib.types.str;
        };
        namedExpression = lib.mkOption {
          type = lib.types.str;
          default = if config.expression == (sqlIdentifier config.name) then sqlIdentifier config.name else "(${config.expression}) AS ${sqlIdentifier config.name}";
          readOnly = true;
          visible = false;
        };
      };
    });
    coercedExpressionType = lib.pipe expressionType
      [
        (lib.types.coercedTo lib.types.str (name: { inherit name; }))
      ];
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
                     type = enum ["=" "!=" "IN"];
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
          type = lib.types.listOf coercedExpressionType;
          default = [];
        };
        fields = lib.mkOption {
          type = lib.types.listOf coercedExpressionType;
        };
        fn = lib.mkOption {
          type = lib.types.enum ["last1" "mean" "derivative" "count"];
        };
        panelQuery = lib.mkOption {
          type = dashboardFormat.type;
        };
      };
      config = {
        rawSql = let
          expressions = lib.concatMapStringsSep ", " (x: x.expression);
          namedExpressions = lib.concatMapStringsSep ", " (x: x.namedExpression);
          names = lib.concatMapStringsSep ", " (x: sqlIdentifier x.name);
          filters = ''(${lib.concatStringsSep ") AND (" (["$__timeFilter(greptime_timestamp)"] ++ (lib.mapAttrsToList sqlFilter config.filter))})'';
        in lib.mkDefault (
          if config.fn == "last1" then ''
            SELECT ${lib.optionalString (config.tags != []) ''DISTINCT ON (${expressions config.tags})''}
              greptime_timestamp,
              ${namedExpressions (config.tags ++ config.fields)}
            FROM
              ${sqlIdentifier config.database}.${sqlIdentifier config.table}
            WHERE
              ${filters}
            ORDER BY ${lib.optionalString (config.tags != []) ''${expressions config.tags},''} greptime_timestamp DESC
          '' else if config.fn == "derivative" then ''
            WITH downsampled AS (
              SELECT DISTINCT ON (${expressions config.tags}, date_bin(interval '$__interval', greptime_timestamp))
                greptime_timestamp, ${namedExpressions (config.tags ++ config.fields)}
              FROM
                ${sqlIdentifier config.database}.${sqlIdentifier config.table}
              WHERE
                ${filters}
              ORDER BY ${expressions config.tags}, date_bin(interval '$__interval', greptime_timestamp), greptime_timestamp DESC
            ),
            binned AS (
              SELECT
                *,
                date_bin(interval '$__interval', greptime_timestamp) AS _time_bucket
              FROM
                downsampled
            ),
            tags AS (
              SELECT DISTINCT
                ${names config.tags}
              FROM downsampled
            ),
            grid AS (
              SELECT
                unnest(generate_series(
                  min(_time_bucket),
                  max(_time_bucket),
                  interval '$__interval'
                )) AS _time_bucket
              FROM binned
            ),
            filled AS (
              SELECT
                ${lib.concatMapStringsSep ", " (x: "t.${sqlIdentifier x.name}") config.tags},
                ${lib.concatMapStringsSep ", " (x: "b.${sqlIdentifier x.name}") config.fields},
                coalesce(greptime_timestamp, _time_bucket) AS greptime_timestamp
              FROM grid
              CROSS JOIN tags t
              LEFT JOIN binned b USING (${names config.tags}, _time_bucket)
            ),
            deltas AS (
              SELECT
                ${names config.tags},
                greptime_timestamp,
                ${lib.concatMapStringsSep ", " (i: "${sqlIdentifier i} - lag(${sqlIdentifier i}) over (partition by ${names config.tags} order by greptime_timestamp) AS ${sqlIdentifier "delta_${i}"}") (["greptime_timestamp"] ++ (lib.map (i: i.name) config.fields))}
              FROM filled
            )
            SELECT
              ${names config.tags},
              greptime_timestamp,
              ${lib.concatMapStringsSep ", " (i: let
                di = sqlIdentifier "delta_${i.name}";
              in "CASE WHEN ${di} < 0 THEN NULL ELSE ${di} / arrow_cast(delta_greptime_timestamp, 'Float64')*1e9 END AS ${sqlIdentifier i.name}") config.fields}
            FROM
              deltas
          '' else if config.fn == "count" then ''
            WITH data AS (
              SELECT
                greptime_timestamp AS original_greptime_timestamp,
                ${names config.tags},
                count(*) AS count
              FROM
                ${sqlIdentifier config.database}.${sqlIdentifier config.table}
              WHERE
                ${filters}
              GROUP BY original_greptime_timestamp, ${names config.tags}
            )
            SELECT
              date_bin(interval '$__interval', original_greptime_timestamp) AS greptime_timestamp,
              ${names config.tags},
              mean("count") as "count"
            FROM
              data
            GROUP BY greptime_timestamp, ${names config.tags}
            ORDER BY greptime_timestamp ASC
          '' else ''
            SELECT
              ${namedExpressions config.tags},
              greptime_timestamp,
              ${lib.concatMapStringsSep ", " (x: "${config.fn}(${x.expression}) RANGE '$__interval' FILL NULL AS ${sqlIdentifier x.name}") config.fields},
            FROM
              ${sqlIdentifier config.database}.${sqlIdentifier config.table}
            WHERE
              ${filters}
            ALIGN '$__interval' BY (${names config.tags})
            ORDER BY greptime_timestamp ASC
          ''
        );
        panelQuery.spec = {
          query = {
            group = "info8fcc-greptimedb-datasource";
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
