{ config, pkgs, lib, ... }:

# Based on https://github.com/bertiebaggio/grafana-zfs-metrics

with import ../../../nix/modules/isz-grafana/lib.nix { inherit config pkgs lib; };
let
  interval = config.isz.telegraf.interval.zpool;
  heatmapPanel = name: args: base (lib.recursiveUpdate {
    panel.title = name;
    panel.interval = interval;
    influx.query = ''
      import "join"

      cumulative = from(bucket: v.defaultBucket)
        |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
        |> filter(fn: (r) => r["_measurement"] == "zpool_latency")
        |> filter(fn: (r) => r["_field"] == "${name}")
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
    panel.type = "heatmap";
    panel.options = {
      calculate = false;
      cellGap = 0;
      color.scheme = "Turbo";
      yAxis.unit = "s";
      cellValues.unit = "short";
      tooltip.yHistogram = true;
      filterValues.le = 1;
    };
  } args);
  base = args: lib.recursiveUpdate {
    influx.filter.host = {
      op = "=~";
      values = ["^\${host:regex}$"];
    };
  } args;
  chart = args: base (lib.recursiveUpdate {
    panel.interval = interval;
    panel.options = {
      tooltip.mode = "multi";
    };
  } args);
in {
  config.isz.grafana.dashboards."Experimental/ZFS" = {
    uid = "avHi3RIg";
    title = "ZFS";
    defaultDatasourceName = "workshop";
    graphTooltip = 1;
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
    panels = [
      (chart {
        panel.title = "Pool Activity";
        panel.gridPos = { x = 0; y = 0; w = 9; h = 8; };
        influx.filter._measurement = "zpool_stats";
        influx.filter._field = ["read_bytes" "write_bytes" "read_ops" "write_ops"];
        influx.filter.vdev = "root";
        influx.fn = "derivative";
        influx.groupBy.fn = "sum";
        panel.fieldConfig.defaults = {
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
      })
      (base {
        panel.title = "Pool Status";
        panel.gridPos = { x = 9; y = 0; w = 5; h = 2; };
        panel.transparent = true;
        influx.filter._measurement = "zpool_stats";
        influx.filter._field = "size";
        influx.filter.vdev = "root";
        influx.fn = "last1";
        influx.extra = ''
          |> group()
          |> last()
          |> keep(columns: ["state"])
        '';
        panel.options.reduceOptions.fields = "/.*/";
        panel.type = "stat";
        panel.options.colorMode = "background";
        panel.fieldConfig.defaults.color = {
          mode = "fixed";
          fixedColor = "semi-dark-blue";
        };
      })
      (chart {
        panel.title = "vdev I/O Active Queues";
        panel.gridPos = { x = 14; y = 0; w = 10; h = 7; };
        influx.filter._measurement = "zpool_vdev_stats";
        influx.filter._field = { op = "=~"; values = "_active_queue$"; };
        influx.filter.vdev = "root";
        influx.fn = "mean";
        influx.imports = ["strings"];
        influx.extra = ''
          |> map(fn: (r) => ({
            r with _field:
              strings.title(v:
                strings.replaceAll(
                  v: strings.trimSuffix(v: r._field, suffix: "_active_queue"),
                  t: "_", u: " "
                )
              )
          }))
          |> drop(columns: ["host", "vdev"])
        '';
        panel.fieldConfig.defaults = {
          unit = "short";
        };
      })
      (base {
        panel.title = "";
        panel.gridPos = { x = 9; y = 2; w = 5; h = 5; };
        influx.filter._measurement = "zpool_stats";
        influx.filter._field = ["read_errors" "write_errors" "fragmentation" "checksum_errors"];
        influx.filter.vdev = "root";
        influx.fn = "last1";
        influx.extra = ''
          |> drop(columns: ["host", "vdev", "state"])
        '';
        panel.type = "stat";
        panel.options.colorMode = "value";
        panel.options.textMode = "value_and_name";
        panel.options.justifyMode = "center";
        panel.fieldConfig.defaults.color = {
          mode = "fixed";
          fixedColor = "semi-dark-red";
        };
        panel.fieldConfig.defaults.unit = "short";
        fields.fragmentation.unit = "percent";
      })
      (base {
        panel.title = "";
        panel.gridPos = { x = 9; y = 7; w = 5; h = 7; };
        influx.filter._measurement = "zpool_stats";
        influx.filter._field = ["alloc" "free" "size"];
        influx.filter.vdev = "root";
        influx.fn = "last1";
        influx.groupBy.fn = "sum";
        panel.type = "stat";
        panel.options.graphMode = "none";
        panel.options.colorMode = "background";
        panel.options.textMode = "value_and_name";
        panel.fieldConfig.defaults.color = {
          mode = "fixed";
          fixedColor = "semi-dark-blue";
        };
        panel.fieldConfig.defaults.unit = "decbytes";
      })
      (chart {
        panel.title = "vdev I/O Pending Queues";
        panel.gridPos = { x = 14; y = 7; w = 10; h = 7; };
        influx.filter._measurement = "zpool_vdev_stats";
        influx.filter._field = { op = "=~"; values = "_pend_queue$"; };
        influx.filter.vdev = "root";
        influx.fn = "mean";
        influx.imports = ["strings"];
        influx.extra = ''
          |> map(fn: (r) => ({
            r with _field:
              strings.title(v:
                strings.replaceAll(
                  v: strings.trimSuffix(v: r._field, suffix: "_pend_queue"),
                  t: "_", u: " "
                )
              )
          }))
          |> drop(columns: ["host", "vdev"])
        '';
        panel.fieldConfig.defaults = {
          unit = "short";
        };
      })
      (chart {
        panel.title = "Pool Usage";
        panel.gridPos = { x = 0; y = 8; w = 9; h = 6; };
        influx.filter._measurement = "zpool_stats";
        influx.filter._field = ["free" "alloc" "size"];
        influx.filter.vdev = "root";
        influx.fn = "mean";
        influx.extra = ''
          |> drop(columns: ["host", "vdev", "state"])
        '';
        panel.fieldConfig.defaults = {
          unit = "decbytes";
        };
      })
      {
        panel.title = "Latencies";
        panel.gridPos = { x = 0; y = 14; w = 24; h = 1; };
        panel.type = "row";
      }
      (heatmapPanel "total_read" {
        panel.title = "Total Reads";
        panel.gridPos = { x = 0; y = 15; w = 12; h = 8; };
        panel.options.color.scheme = "Greens";
      })
      (heatmapPanel "total_write" {
        panel.title = "Total Writes";
        panel.gridPos = { x = 12; y = 15; w = 12; h = 8; };
        panel.options.color.scheme = "Oranges";
      })
      (heatmapPanel "$latencyparam" {
        panel.title = "Latency for $latencyparam queue";
        panel.gridPos = { x = 0; y = 23; w = 6; h = 8; };
        panel.repeat = "latencyparam";
        panel.repeatDirection = "h";
      })
    ];
  };
}
