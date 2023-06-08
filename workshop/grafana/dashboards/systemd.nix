{ config, pkgs, lib, ... }:

{
  config.isz.grafana.dashboards."Experimental/systemd" = {
    uid = "e7207092-4f83-42bc-b84c-c934b22aa909";
    title = "systemd";
    defaultDatasourceName = "workshop";
    panels = [
      {
        panel.gridPos = { x = 0; y = 0; w = 24; h = 9; };
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
        panel.gridPos = { x = 0; y = 9; w = 24; h = 18; };
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
          //|> filter(fn: (r) => r["host"] =~ /^${host:regex}$/)
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
      {
        panel.gridPos = { x = 0; y = 27; w = 24; h = 20; };
        panel.title = "systemd units";
        panel.type = "table";
        panel.interval = "60s";
        panel.fieldConfig.defaults = {
          custom.filterable = true;
        };
        influx.query = ''
          from (bucket: v.defaultBucket)
            |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
            |> filter(fn: (r) => r["_measurement"] == "systemd_unit")
            //|> filter(fn: (r) => r["host"] =~ /^${host:regex}$/)
            |> aggregateWindow(every: v.windowPeriod, fn: last)
            |> filter(fn: (r) => r._field !~ /.*Timestamp$/ or r._value > 0)
            |> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")
            |> group(columns: ["_measurement", "_field", "host", "Id"])
            |> sort(columns: ["_time"])
            //|> aggregateWindow(every: v.windowPeriod, fn: last)
            |> derivative(unit: 1s, nonNegative: true, columns: ["IPIngressBytes", "IPEgressBytes", "IPIngressPackets", "IPEgressPackets", "CPUUsageNSec", "IOReadBytes", "IOWriteBytes", "IOReadOperations", "IOWriteOperations"])
            |> last(column: "_stop")
            |> drop(columns: ["_start", "_stop", "_measurement", "unit_type"])
            |> map(fn: (r) => ({r with
              CPUUsageNSec: r.CPUUsageNSec / 1000000000.,
              ActiveEnterTimestamp: r.ActiveEnterTimestamp/1000,
              ActiveExitTimestamp: r.ActiveExitTimestamp/1000,
              InactiveEnterTimestamp: r.InactiveEnterTimestamp/1000,
              InactiveExitTimestamp: r.InactiveExitTimestamp/1000
            }))
            |> group()
            |> sort(columns: ["host", "Slice", "Id"])
        '';
        fields.CPUUsageNSec.unit = "percentunit";
        fields."/.*Bytes/".unit = "Bps";
        fields."/.*Packets/".unit = "pps";
        fields."/.*Operations/".unit = "iops";
        fields."/.*Timestamp/".unit = "dateTimeAsLocalNoDateIfToday";
        fields.MemoryCurrent.unit = "bytes";
        fields.NRestarts = {
          color.mode = "thresholds";
          thresholds.mode = "absolute";
          thresholds.steps = [
            { value = null; color = "green"; }
            { value = 1; color = "red"; }
          ];
        };
        fields."ControlGroup\\field".custom.width = 352;
      }
    ];
  };
}
