{ config, pkgs, lib, ... }:

{
  config.isz.grafana.dashboards."Experimental/systemd" = {
    uid = "e7207092-4f83-42bc-b84c-c934b22aa909";
    title = "systemd";
    defaultDatasourceName = "workshop";
    panels = [
      {
        panel.gridPos = { x = 0; y = 0; w = 24; h = 18; };
        panel.title = "CPU Usage";
        panel.type = "table";
        panel.fieldConfig.defaults = {
          custom.filterable = true;
        };
        panel.interval = "60s";
        influx.filter._measurement = "systemd_unit";
        influx.filter._field = "CPUUsageNSec";
        influx.fn = "derivative";
        influx.extra = ''
          |> map(fn: (r) => ({r with _value: r._value / 1000000000.}))
        '';
        panel.fieldConfig.defaults = {
          unit = "percentunit";
        };
        panel.transformations = [
          { id = "timeSeriesTable"; }
        ];
      }
      {
        panel.gridPos = { x = 0; y = 18; w = 24; h = 9; };
        panel.title = "Unit CPU usage";
        panel.interval = "60s";
        influx.query = ''
          import "join"

          systemd = from(bucket: v.defaultBucket)
            |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
            |> filter(fn: (r) => r["_measurement"] == "systemd_unit")
            |> filter(fn: (r) => r["_field"] == "CPUUsageNSec")
            |> aggregateWindow(every: v.windowPeriod, fn: last, createEmpty: false)
            |> derivative(unit: 1s, nonNegative: true)
            |> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")
            |> map(fn: (r) => ({r with
              path: if exists r.ControlGroup and r.ControlGroup != "" then ("/sys/fs/cgroup" + (if r.ControlGroup == "/" then "" else r.ControlGroup)) else ("/unit/" + r.Id),
              Slice: if exists r.Slice then r.Slice else ""
            }))
            |> drop(columns: ["_measurement", "_start", "_stop", "ControlGroup"])
            |> group(columns: ["host", "path"])

          cgroup = from(bucket: v.defaultBucket)
            |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
            |> filter(fn: (r) => r["_measurement"] == "cgroup")
            |> filter(fn: (r) => r["_field"] == "cpu.stat.user_usec" or r["_field"] == "cpu.stat.system_usec")
            |> aggregateWindow(every: v.windowPeriod, fn: last, createEmpty: false)
            |> derivative(unit: 1s, nonNegative: true)
            |> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")
            |> drop(columns: ["_measurement", "_start", "_stop"])
            |> group(columns: ["host", "path"])

          join.full(
            left: systemd,
            right: cgroup,
            on: (l, r) => (l.host == r.host and l.path == r.path and l._time == r._time),
            as: (l, r) => {
              time = if exists l._time then l._time else r._time
              host = if exists l.host then l.host else r.host
              path = if exists l.path then l.path else r.path
              return {_time: time, host: host, path: path, Id: l.Id, unit_type: l.unit_type,
              Slice: l.Slice,
              CPUUsageNSec: l.CPUUsageNSec,
              "cpu.stat.user_usec": r["cpu.stat.user_usec"],
              "cpu.stat.system_usec": r["cpu.stat.system_usec"]
              }
            })
            |> group(columns: ["_start", "_stop", "host", "path", "Id", "Slice", "unit_type"])
        '';
      }
      {
        panel.gridPos = { x = 0; y = 27; w = 24; h = 18; };
        panel.title = "trend test";
        panel.type = "table";
        panel.fieldConfig.defaults = {
          custom.filterable = true;
        };
        panel.interval = "60s";
        influx.query = ''
          from (bucket: v.defaultBucket)
          |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
          //|> filter(fn: (r) => r["_field"] == "IOReadBytes" or r["_field"] == "IOWriteBytes")
          |> filter(fn: (r) => r["_measurement"] == "systemd_unit")
          |> filter(fn: (r) => r._field != "ActiveState")
          //|> filter(fn: (r) => r["host"] =~ /^''${host:regex}$/)
          |> aggregateWindow(every: v.windowPeriod, fn: last)
          |> derivative(unit: 1s, nonNegative: true)
          |> map(fn: (r) => ({r with field: r._field}))
          |> group(columns: ["_start", "_stop", "host", "Id", "Slice", "unit_type", "ControlGroup", "field", "_measurement", "_field"])
        '';
        fields.CPUUsageNSec.unit = "percentunit";
        fields."/.*Bytes/".unit = "Bps";
        fields.MemoryCurrent.unit = "bytes";
        fields."ControlGroup\\field".custom.width = 352;
        panel.transformations = [
          { id = "timeSeriesTable"; }
          {
            id = "groupingToMatrix";
            options = {
              columnField = "field";
              emptyValue = "null";
              rowField = "ControlGroup";
              valueField = "Trend";
            };
          }
        ];
      }
      (let
        fields = [
          { name = "host"; }
          { name = "Slice"; properties.custom.hidden = true; }
          { name = "Id"; properties.custom.hidden = true; }
          {
            name = "ControlGroup"; value = ''
              if (exists r.ControlGroup and r.ControlGroup != "") then r.ControlGroup else ((if (exists r.Slice and r.Slice != "" and r.Slice != "-.slice") then "/" + r.Slice else "") + "/" + r.Id + " (missing)")
            '';
            properties = {
              custom.width = 400;
            };
          }
          {
            name = "State"; value = ''
              r.ActiveState + (if exists r.SubState then "/" + r.SubState else "")
            '';
            properties.custom.width = 115;
          }
          {
            name = "Uptime";
            unit = "dateTimeFromNow";
            value = ''
              if r.ActiveState == "active" then r.ActiveEnterTimestamp/1000 else debug.null(type: "int")
            '';
            properties.custom.width = 110;
          }
          {
            name = "NRestarts";
            properties = {
              custom.width = 100;
              custom.cellOptions.type = "color-background";
              color.mode = "thresholds";
              thresholds.mode = "absolute";
              thresholds.steps = [
                { value = null; color = "transparent"; }
                { value = 0; color = "green"; }
                { value = 1; color = "red"; }
              ];
            };
          }
          {
            name = "CPU";
            unit = "percentunit";
            value = ''
              r.CPUUsageNSec / 1000000000.
            '';
            properties.custom.width = 90;
            properties.decimals = 1;
          }
          {
            name = "Memory";
            unit = "bytes";
            value = ''
              r.MemoryCurrent
            '';
            properties.custom.width = 90;
          }
          { name = "IPIngressBytes"; unit = "Bps"; }
          { name = "IPEgressBytes"; unit = "Bps"; }
          { name = "IPIngressPackets"; unit = "pps"; }
          { name = "IPEgressPackets"; unit = "pps"; }
          { name = "IOReadBytes"; unit = "Bps"; }
          { name = "IOWriteBytes"; unit = "Bps"; }
          { name = "IOReadOperations"; unit = "iops"; }
          { name = "IOWriteOperations"; unit = "iops"; }
        ];
        queryRecord = lib.concatMapStringsSep ",\n" (field: let
          name = lib.strings.escapeNixIdentifier field.name;
          value = field.value or "r[${lib.strings.escapeNixString field.name}]";
          in ''  ${name}: ${value}''
        ) fields;
      in {
        panel.gridPos = { x = 0; y = 45; w = 24; h = 20; };
        panel.title = "systemd units";
        panel.type = "table";
        panel.interval = "60s";
        panel.fieldConfig.defaults = {
          custom.filterable = true;
        };
        influx.query = ''
          import "internal/debug"
          from (bucket: v.defaultBucket)
            |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
            |> filter(fn: (r) => r["_measurement"] == "systemd_unit")
            |> filter(fn: (r) => (not exists r.LoadState or r.LoadState != "not-found"))
            //|> filter(fn: (r) => r["host"] =~ /^''${host:regex}$/)
            |> aggregateWindow(every: v.windowPeriod, fn: last, createEmpty: false)
            |> filter(fn: (r) => r._field !~ /.*Timestamp$/ or int(v: r._value) > 0)
            |> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")
            |> group(columns: ["_measurement", "_field", "host", "Id"])
            |> sort(columns: ["_time"])
            //|> aggregateWindow(every: v.windowPeriod, fn: last)
            |> derivative(unit: 1s, nonNegative: true, columns: ["IPIngressBytes", "IPEgressBytes", "IPIngressPackets", "IPEgressPackets", "CPUUsageNSec", "IOReadBytes", "IOWriteBytes", "IOReadOperations", "IOWriteOperations"])
            |> last(column: "_stop")
            |> drop(columns: ["_start", "_stop", "_measurement", "unit_type"])
            |> map(fn: (r) => ({
              ${queryRecord}
            }))
            |> group()
        '';
        fields = builtins.listToAttrs (builtins.map (field: lib.nameValuePair field.name ({
          unit = lib.mkIf (field ? unit) field.unit;
        } // (field.properties or {}))) fields);
        fieldOrder = builtins.map (field: field.name) fields;
        panel.transformations = lib.mkBefore [
          {
            id = "sortBy";
            options.sort = [
              { field = "host"; }
              { field = "ControlGroup"; }
            ];
          }
        ];
      })
      {
        panel.gridPos = { x = 0; y = 65; w = 24; h = 20; };
        panel.type = "volkovlabs-echarts-panel";
        panel.title = "Unit Memory Usage";
        influx.filter._measurement = "systemd_unit";
        influx.filter._field = "MemoryCurrent";
        influx.filter.host = "workshop.isz.wtf";
        influx.fn = "last1";
        influx.imports = ["regexp"];
        influx.extra = ''
          |> map(fn: (r) => ({r with ControlGroup: if (exists r.ControlGroup and r.ControlGroup != "") then r.ControlGroup else ((if (exists r.Slice and r.Slice != "" and r.Slice != "-.slice") then "/" + r.Slice else "") + "/" + r.Id)}))
          |> map(fn: (r) => ({r with Parent: if exists r.Slice then regexp.replaceAllString(r: /^(((.+)\/)|(\/))[^\/]+$/, v: r.ControlGroup, t: "$3$4") else ""}))
          |> group(columns: ["_start", "_stop", "_measurement", "_field", "ControlGroup", "Slice", "host", "Id", "LoadState", "unit_type", "Parent"])
        '';
        panel.options = {
          renderer = "canvas";
          getOption = ''
            const { getValueFormat, formattedValueToString } = System.get(System.resolve("@grafana/data"));

            const memoryCurrent = data.series.map((s) => s.fields.find(f => f.name == "MemoryCurrent"));

            const seriesData = memoryCurrent.map(
              (f) => ({
                id: f.labels.ControlGroup,
                labelText: f.labels.Id,
                value: (f.values.buffer || f.values)[0],
                depth: (f.labels.ControlGroup == "/") ? 0 : (Array.from(f.labels.ControlGroup).filter(c => c == "/").length),
              })
            );

            const links = memoryCurrent.map(
              (f) => {
                return {
                  source: f.labels.Parent || "",
                  target: f.labels.ControlGroup,
                  value: (f.values.buffer || f.values)[0],
                }
              }
            );

            const bytesFormat = getValueFormat("bytes");

            const series = {
              type: 'sankey',
              layout: 'none',
              emphasis: {
                focus: 'trajectory'
              },
              label: { formatter: params => params.data.labelText },
              edgeLabel: {
                show: true,
                formatter: params => formattedValueToString(bytesFormat(params.value, undefined, undefined, undefined))
              },
              data: seriesData,
              links: links
            }

            return {
              backgroundColor: 'transparent',
              series,
            };
          '';
        };
      }
    ];
  };
}
