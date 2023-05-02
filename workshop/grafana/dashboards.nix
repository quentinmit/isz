{ config, pkgs, lib, ... }:

let
  blankDashboard = {
    annotations.list = [{
      builtIn = 1;
      datasource.type = "grafana";
      datasource.uid = "-- Grafana --";
      enable = true;
      hide = true;
      iconColor = "rgba(0, 211, 255, 1)";
      name = "Annotations & Alerts";
      target.limit = 100;
      target.matchAny = false;
      target.tags = [];
      target.type = "dashboard";
      type = "dashboard";
    }];
    #version = 0;
    schemaVersion = 38;
    #editable = true;
    #graphTooltip = 0;
    #links = [];
    #liveNow = false;
    #fiscalYearStartMonth = 0;
    #refresh = "";
    #style = "dark";
    #tags = [];
    #templating.list = [];
    #time.from = "now-6h";
    #time.to = "now";
    #timepicker = {};
    #timezone = "";
    #weekStart = "";
    panels = [];
  };
  influxDatasource = {
    uid = "mAU691fGz";
    type = "influxdb";
  };
  muninGraphs = [
    {
      graph_title = "Disk IOs per device";
      graph_vlabel = "IOs/second read (-) / write (+)";
      graph_category = "disk";
      influx.filter._measurement = "diskio";
      influx.filter._field = ["reads" "writes"];
      influx.fn = "derivative";
      influx.pivot = true;
      unit = "iops";
      fields.reads.negative = true;
    }
    {
      graph_title = "Disk latency per device";
      graph_vlabel = "Average IO Wait";
      graph_category = "disk";
      influx.filter._measurement = "diskio";
      influx.filter._field = ["read_time" "write_time" "reads" "writes"];
      influx.fn = "derivative";
      influx.pivot = true;
      influx.extra = ''
        |> map(fn: (r) => ({_time: r._time, host: r.host, name: r.name, _value: if (r.reads + r.writes == 0) then 0. else float(v: r.read_time + r.write_time) / float(v: r.reads + r.writes)}))
      '';
      unit = "ms";
    }
    {
      graph_title = "Disk usage in percent";
      graph_category = "disk";
      influx.filter._measurement = "disk";
      influx.filter._field = "used_percent";
      influx.fn = "mean";
      unit = "percent";
    }
  ];
  fluxValue = str: ''"${lib.escape [''"''] str}"'';
  muninPanel = g: {
    gridPos = {
      w = 12;
      h = 8;
    };
    title = g.graph_title;
    type = "timeseries";
    interval = "10s";
    fieldConfig.defaults = {
      custom.axisLabel = g.graph_vlabel or null;
      unit = g.unit;
    };
    fieldConfig.overrides = lib.mapAttrsToList (field: options: {
      matcher.id = "byName";
      matcher.options = field;
      properties = lib.optional options.negative {
        id = "custom.transform";
        value = "negative-Y";
      };
    }) (g.fields or {});
    datasource = influxDatasource;
    targets = let
      filters = lib.mapAttrsToList (field: values:
        ''|> filter(fn: (r) => ${lib.concatMapStringsSep " or " (value: ''r[${fluxValue field}] == ${fluxValue value}'') (lib.toList values)})'') g.influx.filter;
    in [{
      datasource = influxDatasource;
      query = ''
      from (bucket: v.defaultBucket)
      |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
      ${lib.concatStringsSep "\n" filters}
      |> filter(fn: (r) => r.host =~ /^''${host:regex}$/)
      '' + (if g.influx.fn == "derivative" then ''
      |> aggregateWindow(every: v.windowPeriod, fn: last)
      |> derivative(unit: 1s, nonNegative: true)
      '' else ''
      |> aggregateWindow(every: v.windowPeriod, fn: ${g.influx.fn}, createEmpty: false)
      '')+ lib.optionalString (g.influx.pivot or false) ''
      |> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")
      |> drop(columns: ["_start", "_stop"])
      '' + (g.influx.extra or "");
      refId = "A";
    }];
  };
in {
  config = {
    services.grafana.provision.dashboards.settings.providers = let
      dashboards = {
        "Experimental/munin-generated" = {
          uid = "Pd7zBps4z";
          title = "Munin Generated";
          templating.list = [(let
            query = ''
              import "influxdata/influxdb/schema"

              schema.tagValues(
                bucket: v.defaultBucket,
                tag: "host",
                predicate: (r) => r["_measurement"] == "system",
                start: v.timeRangeStart,
                stop: v.timeRangeStop
              )
            '';
            in {
              datasource = influxDatasource;
              definition = query;
              includeAll = true;
              label = "Host";
              multi = true;
              name = "host";
              inherit query;
              type = "query";
            })];
          panels = map muninPanel muninGraphs;
        };
      };
      dashboardFormat = pkgs.formats.json {};
      dashboardPkg = pkgs.linkFarm "grafana-dashboards" (
        lib.mapAttrs' (name: d: lib.nameValuePair "${name}.json" (
          dashboardFormat.generate "${name}.json" (blankDashboard // d)
        )) dashboards
      );
    in [{
      options.path = "${dashboardPkg}";
      options.foldersFromFilesStructure = true;
    }];
  };
}
