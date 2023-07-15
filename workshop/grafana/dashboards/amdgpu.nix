{ config, pkgs, lib, ... }:

with import ../../../nix/modules/isz-grafana/lib.nix { inherit config pkgs lib; };
let
  heatmapPanel = name: unit: let
    scalingFactor = if unit == "MHz" then 1000000.0 else 1.0;
    unitName = if unit == "MHz" then "hertz" else unit;
  in {
    panel.title = name;
    panel.gridPos = { x = 0; y = 0; w = 12; h = 8; };
    influx.query = ''
      import "join"

      cumulative = from(bucket: v.defaultBucket)
        |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
        |> filter(fn: (r) => r["_measurement"] == "amdgpu")
        |> filter(fn: (r) => r["_field"] == "${name}_bucket")
        |> filter(fn: (r) => r["host"] =~ /^''${host:regex}$/)
        |> aggregateWindow(every: v.windowPeriod, fn: last, createEmpty: false)
        |> difference(nonNegative: true, columns: ["_value"])
        |> group(columns: ["_value", "le"], mode: "except")
        |> map(fn: (r) => ({r with le: float(v: r.le) * ${fluxValue scalingFactor}}))

      zeros = cumulative |> first()
        |> map(fn: (r) => ({r with _value: 0, le: 0.0}))

      buckets = union(tables: [zeros, cumulative])
        |> sort(columns: ["le"])
        |> difference(nonNegative: true)
        |> keep(columns: ["_time", "_value", "le"])
        |> group(columns: ["_time", "le"])
        |> sum()
        |> group()

      counts = from(bucket: v.defaultBucket)
        |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
        |> filter(fn: (r) => r["_measurement"] == "amdgpu")
        |> filter(fn: (r) => r["_field"] == "${name}_count")
        |> filter(fn: (r) => r["host"] =~ /^''${host:regex}$/)
        |> aggregateWindow(every: v.windowPeriod, fn: last, createEmpty: false)
        |> difference(nonNegative: true, columns: ["_value"])
        |> group(columns: ["_time"])
        |> sum()
        |> group()
        |> keep(columns: ["_time", "_value"])

      joined = join.inner(
        left: buckets,
        right: counts,
        on: (l, r) => l._time == r._time,
        as: (l, r) => ({l with counts: r._value}),
      )
        |> group(columns: ["le"])
        |> map(fn: (r) => ({_time: r._time, _value: float(v: r._value)/float(v: r.counts), le: r.le}))
      joined
    '';
    panel.type = "heatmap";
    panel.options = {
      calculate = false;
      cellGap = 0;
      color.scheme = "Turbo";
      yAxis.unit = unitName;
      cellValues.unit = "percentunit";
      tooltip.yHistogram = true;
      filterValues.le = -1; # Don't filter cells
    };
  };
in {
  config.isz.grafana.dashboards."Experimental/amdgpu" = {
    uid = "b1b8a9c9-47ce-4951-9f7c-4571bb38afd7";
    title = "amdgpu";
    defaultDatasourceName = "workshop";
    variables = {
      host = {
        predicate = ''r["_measurement"] == "amdgpu"'';
        extra.label = "Host";
        extra.includeAll = false;
      };
    };
    panels = [
      (heatmapPanel "average_core_power" "mwatt")
      (heatmapPanel "average_cpu_power" "mwatt")
      (heatmapPanel "current_coreclk" "MHz")
    ];
  };
}
