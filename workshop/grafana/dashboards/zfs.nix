{ config, pkgs, lib, ... }:

# Based on https://github.com/bertiebaggio/grafana-zfs-metrics

with import ../../../nix/modules/isz-grafana/lib.nix { inherit config pkgs lib; };
let
  interval = config.isz.telegraf.interval.zpool;
  heatmap = { name, config, ... }: {
    options._field = lib.mkOption {
      type = lib.types.str;
      default = name;
    };
    config = {
      spec.title = lib.mkDefault name;
      spec.data.spec.queryOptions.interval = interval;
      influx.query = ''
        import "join"

        cumulative = from(bucket: v.defaultBucket)
          |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
          |> filter(fn: (r) => r["_measurement"] == "zpool_latency")
          |> filter(fn: (r) => r["_field"] == "${config._field}")
          |> filter(fn: (r) => r["host"] =~ /^''${host:regex}$/)
          |> filter(fn: (r) => r["vdev"] == "root")
          |> aggregateWindow(every: v.windowPeriod, fn: last, createEmpty: false)
          |> difference(nonNegative: true, columns: ["_value"])
          |> group(columns: ["_value", "le"], mode: "except")
          |> map(fn: (r) => ({r with le: float(v: r.le)}))

        zeros = cumulative |> first()
          |> map(fn: (r) => ({r with _value: 0, le: 0.0}))

        union(tables: [zeros, cumulative])
          |> sort(columns: ["le"])
          |> difference(nonNegative: true)
          |> keep(columns: ["_time", "_value", "le"])
          |> group(columns: ["le"])
      '';
      spec.vizConfig.group = "heatmap";
      spec.vizConfig.spec.options = {
        calculate = false;
        cellGap = 0;
        color.scheme = lib.mkDefault "Turbo";
        yAxis.unit = "s";
        cellValues.unit = "short";
        tooltip.yHistogram = true;
        filterValues.le = 1;
      };
    };
  };
  vdevQueue = title: prefix: {
    spec.title = "vdev I/O ${title} Queues";
    influx.filter._measurement = "zpool_vdev_stats";
    influx.filter._field = { op = "=~"; values = "_${prefix}_queue$"; };
    influx.filter.vdev = "root";
    influx.fn = "mean";
    influx.imports = ["strings"];
    influx.extra = ''
      |> map(fn: (r) => ({
        r with _field:
          strings.title(v:
            strings.replaceAll(
              v: strings.trimSuffix(v: r._field, suffix: "_${prefix}_queue"),
              t: "_", u: " "
            )
          )
      }))
      |> drop(columns: ["host", "vdev"])
    '';
    spec.vizConfig.spec.fieldConfig.defaults = {
      unit = "short";
    };
  };
in {
  config.isz.grafana.dashboardsV2."zfs" = { ... }: {
    imports = [({ ... }: {
      options.panels = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
          config = {
            influx.filter.host = lib.mkDefault {
              op = "=~";
              values = ["^\${host:regex}$"];
            };
            spec.data.spec.queryOptions.interval = lib.mkIf (config.spec.vizConfig.group == "timeseries") interval;
            spec.vizConfig.spec.options = lib.mkIf (config.spec.vizConfig.group == "timeseries") {
              tooltip.mode = "multi";
            };
          };
        }));
      };
    })];
    config = {
      title = "ZFS";
      defaultDatasourceName = "workshop";
      spec.cursorSync = "Crosshair";
      variables = {
        host = {
          predicate = ''r["_measurement"] == "zpool_stats"'';
          extra.label = "Host";
          extra.includeAll = false;
        };
        latencyparam = {
          predicate = ''r["_measurement"] == "zpool_latency" and r["_field"] !~ /^total_/'';
          tag = "_field";
          extra.label = "Latency Parameters";
          extra.multi = true;
        };
      };
      layout.kind = "TabsLayout";
      layout.spec.tabs = [
        {
          spec.title = "Overview";
          spec.layout.kind = "RowsLayout";
          spec.layout.spec.rows = [
            {
              spec.layout.kind = "GridLayout";
              spec.title = "";
              spec.hideHeader = true;
              spec.layout.spec.items = [
                { spec = {
                    element.name = "pool-activity";
                    x = 0; y = 0; width = 9; height = 8;
                  }; }
                { spec = {
                    element.name = "pool-usage";
                    x = 0; y = 8; width = 9; height = 6;
                  }; }
                { spec = {
                    element.name = "pool-status";
                    x = 9; y = 0; width = 5; height = 2;
                  }; }
                { spec = {
                    element.name = "zpool-errors";
                    x = 9; y = 2; width = 5; height = 5;
                  }; }
                { spec = {
                    element.name = "zpool-usage-stat";
                    x = 9; y = 7; width = 5; height = 7;
                  }; }
                { spec = {
                    element.name = "vdev-queue-active";
                    x = 14; y = 0; width = 10; height = 7;
                  }; }
                { spec = {
                    element.name = "vdev-queue-pend";
                    x = 14; y = 7; width = 10; height = 7;
                  }; }
              ];
            }
            {
              spec.title = "Latencies";
              spec.layout.kind = "GridLayout";
              spec.layout.spec.items = [
                { spec = {
                    element.name = "total_read";
                    x = 0; y = 0; width = 12; height = 8;
                  }; }
                { spec = {
                    element.name = "total_write";
                    x = 12; y = 0; width = 12; height = 8;
                  }; }
                { spec = {
                    element.name = "latency-per-queue";
                    x = 0; y = 8; width = 24; height = 8;
                    repeat = {
                      direction = "h";
                      mode = "variable";
                      value = "latencyparam";
                    };
                  }; }
              ];
            }
          ];
        }
        {
          spec.title = "vdevs";
          spec.layout.kind = "AutoGridLayout";
          spec.layout.spec.fillScreen = true;
          spec.layout.spec.items = [
            { spec.element.name = "vdev-list"; }
          ];
        }
        {
          spec.title = "Datasets";
          spec.layout.kind = "AutoGridLayout";
          spec.layout.spec.fillScreen = true;
          spec.layout.spec.items = [
            { spec.element.name = "dataset-list"; }
          ];
        }
      ];
      panels.pool-activity = {
        spec.title = "Pool Activity";
        influx.filter._measurement = "zpool_stats";
        influx.filter._field = ["read_bytes" "write_bytes" "read_ops" "write_ops"];
        influx.filter.vdev = "root";
        influx.fn = "derivative";
        influx.groupBy.fn = "sum";
        spec.vizConfig.spec.fieldConfig.defaults = {
          unit = "Bps";
        };
        fields.read_ops = {
          custom.axisPlacement = "right";
          unit = "iops";
        };
        fields.write_ops = {
          custom.axisPlacement = "right";
          unit = "iops";
        };
      };
      panels.pool-status = {
        spec.title = "Pool Status";
        spec.transparent = true;
        influx.filter._measurement = "zpool_stats";
        influx.filter._field = "size";
        influx.filter.vdev = "root";
        influx.fn = "last1";
        influx.extra = ''
          |> group()
          |> last()
          |> keep(columns: ["state"])
        '';
        spec.vizConfig.group = "stat";
        spec.vizConfig.spec.options.reduceOptions.fields = "/.*/";
        spec.vizConfig.spec.options.colorMode = "background";
        spec.vizConfig.spec.fieldConfig.defaults.color = {
          mode = "fixed";
          fixedColor = "semi-dark-blue";
        };
      };
      panels.pool-usage = {
        spec.title = "Pool Usage";
        influx.filter._measurement = "zpool_stats";
        influx.filter._field = ["free" "alloc" "size"];
        influx.filter.vdev = "root";
        influx.fn = "mean";
        influx.extra = ''
          |> drop(columns: ["host", "vdev", "state"])
        '';
        spec.vizConfig.spec.fieldConfig.defaults = {
          unit = "decbytes";
        };
      };
      panels.zpool-errors = {
        influx.filter._measurement = "zpool_stats";
        influx.filter._field = ["read_errors" "write_errors" "fragmentation" "checksum_errors"];
        influx.filter.vdev = "root";
        influx.fn = "last1";
        influx.extra = ''
          |> drop(columns: ["host", "vdev", "state"])
        '';
        spec.vizConfig.group = "stat";
        spec.vizConfig.spec = {
          options.colorMode = "value";
          options.textMode = "value_and_name";
          options.justifyMode = "center";
          fieldConfig.defaults.color = {
            mode = "fixed";
            fixedColor = "semi-dark-red";
          };
          fieldConfig.defaults.unit = "short";
        };
        fields.fragmentation.unit = "percent";
      };
      panels.zpool-usage-stat = {
        influx.filter._measurement = "zpool_stats";
        influx.filter._field = ["alloc" "free" "size"];
        influx.filter.vdev = "root";
        influx.fn = "last1";
        influx.groupBy.fn = "sum";
        spec.vizConfig.group = "stat";
        spec.vizConfig.spec.options.graphMode = "none";
        spec.vizConfig.spec.options.colorMode = "background";
        spec.vizConfig.spec.options.textMode = "value_and_name";
        spec.vizConfig.spec.fieldConfig.defaults.color = {
          mode = "fixed";
          fixedColor = "semi-dark-blue";
        };
        spec.vizConfig.spec.fieldConfig.defaults.unit = "decbytes";
      };
      panels.vdev-queue-active = vdevQueue "Active" "active";
      panels.vdev-queue-pend = vdevQueue "Pending" "pend";
      panels.total_read = { ... }: {
        imports = [ heatmap ];
        config.spec = {
          title = "Total Reads";
          vizConfig.spec.options.color.scheme = "Greens";
        };
      };
      panels.total_write = { ... }: {
        imports = [ heatmap ];
        config.spec = {
          title = "Total Writes";
          vizConfig.spec.options.color.scheme = "Oranges";
        };
      };
      panels.latency-per-queue = { ... }: {
        imports = [ heatmap ];
        config = {
          _field = "$latencyparam";
          spec.title = "Latency for $latencyparam queue";
        };
      };
      panels.vdev-list = {
        spec.title = "vdevs";
        influx.filter._measurement = "zpool_stats";
        influx.filter._field = ["read_errors" "write_errors" "fragmentation" "checksum_errors"];
        influx.fn = "last1";
        influx.groupBy = {
          fields = [
            "_measurement"
            "_field"
            "host"
            "name"
            "path"
            "vdev"
          ];
          fn = "last1";
        };
        influx.pivot = true;
        influx.extra = ''
          |> drop(columns: ["_measurement", "host"])
          |> group()
        '';
        influx.panelQuery.spec.hidden = true;
        spec.data.spec.queries = [{
          spec = {
            query = {
              group = "__expr__";
              datasource.name = "__expr__";
              spec.type = "sql";
              spec.expression = ''
                SELECT
                  CONCAT(name, "/", vdev) AS vdev,
                  TRIM(TRAILING "/" FROM
                    REGEXP_SUBSTR(
                      CONCAT(name, "/", vdev),
                      "^[^/]+/.+/"
                    )
                  ) AS parent,
                  path,
                  read_errors, write_errors, fragmentation, checksum_errors
                FROM A
              '';
            };
            refId = "B";
          };
        }];
        spec.vizConfig = {
          group = "equansdatahub-tree-panel";
          version = "1.7.7";
          spec.options = {
            idColumn = "vdev";
            labelColumn = "vdev";
            parentIdColumn = "parent";
            additionalColumns = "read_errors,write_errors,fragmentation,checksum_errors";
            displayedTreeDepth = 100;
            dashboardVariableName = "vdev";
            showColumnHeaders = true;
          };
        };
      };
      panels.dataset-list = let
        fields = [
          "used"
          "usedbydataset"
          "usedbysnapshots"
          "available"
          "referenced"
        ];
      in {
        spec.title = "Datasets";
        influx.filter._measurement = "zfs_resource";
        influx.filter._field = fields;
        influx.fn = "last1";
        influx.groupBy = {
          fields = [
            "_measurement"
            "_field"
            "host"
            "name"
          ];
          fn = "last1";
        };
        influx.pivot = true;
        influx.extra = ''
          |> drop(columns: ["_measurement", "host"])
          |> group()
        '';
        influx.panelQuery.spec.hidden = true;
        spec.data.spec.queries = [{
          spec = {
            query = {
              group = "__expr__";
              datasource.name = "__expr__";
              spec.type = "sql";
              spec.expression = ''
                SELECT
                  name,
                  TRIM(TRAILING "/" FROM
                    REGEXP_SUBSTR(
                      name,
                      "^.+/"
                    )
                  ) AS parent,
                  ${lib.concatStringsSep ", " fields}
                FROM A
              '';
            };
            refId = "B";
          };
        }];
        spec.vizConfig = {
          group = "equansdatahub-tree-panel";
          version = "1.7.7";
          spec.options = {
            idColumn = "name";
            labelColumn = "name";
            parentIdColumn = "parent";
            additionalColumns = lib.concatStringsSep "," fields;
            displayedTreeDepth = 100;
            dashboardVariableName = "dataset";
            showColumnHeaders = true;
          };
        };
      };

    };
  };
}
