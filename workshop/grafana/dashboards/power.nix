{ config, pkgs, lib, ... }:

{
  config.isz.grafana.dashboards."Workshop Power" = let
    channelGraph = { field, integralField, filter }: args: lib.recursiveUpdate {
        influx = [
          {
            bucket = "profinet";
            filter = {
              _measurement = "caparoc";
              _field = ["total_${integralField}" "total_time_seconds"];
            } // filter;
            fn = null;
            extra = ''
              |> window(every: v.windowPeriod)
              |> last()
              |> window(every: inf)
              |> difference(nonNegative: true)
              |> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")
              |> map(fn: (r) => ({r with average_${field}: r.total_${integralField}/r.total_time_seconds}))
              |> drop(columns: ["total_${integralField}", "total_time_seconds"])
              |> yield(name: "mean")
            '';
          }
          {
            bucket = "profinet";
            filter = {
              _measurement = "caparoc";
              _field = "min_${field}";
            } // filter;
            fn = "min";
          }
          {
            bucket = "profinet";
            filter = {
              _measurement = "caparoc";
              _field = "max_${field}";
            } // filter;
            fn = "max";
          }
        ];
        panel.fieldConfig.defaults = {
          color.mode = "fixed";
          custom.lineWidth = 0;
          custom.fillOpacity = 0;
        };
        panel.options.tooltip.mode = "multi";
        fields."average_${field}" = {
          displayName = "Average";
          color = { mode = "fixed"; fixedColor = "green"; };
          custom.lineWidth = 1;
        };
        fields."max_${field}" = {
          displayName = "Max";
          custom.fillOpacity = 25;
          custom.fillBelowTo = "min_${field}";
        };
        fields."min_${field}".displayName = "Min";
        panel.interval = "1s";
    } args;
  in {
    uid = "f96fd7e1-33eb-47c1-89ec-e8fe2741e043";
    title = "Workshop Power";
    defaultDatasourceName = "workshop";
    graphTooltip = 2;
    variables = {
      caparoc_channel = {
        query = ''
          from(bucket: "profinet")
            |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
            |> filter(fn: (r) => r["_measurement"] == "caparoc")
            |> filter(fn: (r) => r["_field"] == "status")
            |> last()
            |> group(columns: ["channel"])
            |> sort(columns: ["_time"])
            |> last()
            |> keep(columns: ["channel", "channel_name"])
            |> group()
            |> map(fn: (r) => ({
              _value: r.channel + " " + (
                if exists r.channel_name then r.channel_name else "Channel " + r.channel
              )
            }))
            |> yield(name: "last")
        '';
        extra.hide = 2; # show nothing
        extra.includeAll = true;
        extra.regex = ''/(?<value>\S+)\s+(?<text>.+)/'';
      };
    };
    panels = [
      # Battery
      {
        panel.gridPos = { x = 0; y = 0; w = 2; h = 8; };
        panel.title = "Battery Voltage";
        panel.type = "gauge";
        influx.filter._measurement = "epicpwrgate.status";
        influx.filter._field = "Bat.V";
        influx.fn = "last1";
        panel.fieldConfig.defaults = {
          unit = "volt";
          decimals = 1;
          min = 10;
          max = 16;
        };
        panel.options.tooltip.mode = "multi";
      }
      {
        panel.gridPos = { x = 2; y = 0; w = 10; h = 8; };
        panel.title = "Voltage";
        influx.filter._measurement = "epicpwrgate.status";
        influx.filter._field = ["Bat.V" "PS.V"];
        influx.fn = "mean";
        panel.fieldConfig.defaults = {
          unit = "volt";
          decimals = 2;
        };
        panel.options.tooltip.mode = "multi";
        fields."Bat.V".displayName = "Battery Voltage";
        fields."PS.V".displayName = "PSU Voltage";
      }
      {
        panel.gridPos = { x = 12; y = 0; w = 10; h = 8; };
        panel.title = "Battery Temperature";
        influx.filter._measurement = "epicpwrgate.status";
        influx.filter._field = "Temp";
        influx.fn = "mean";
        influx.extra = ''
          |> map(fn: (r) => ({r with _value: (r._value - 32.) * 5./9.}))
        '';
        panel.fieldConfig.defaults = {
          unit = "celsius";
          decimals = 2;
        };
        panel.options.tooltip.mode = "multi";
      }
      # Total Current/Power
      {
        panel.gridPos = { x = 0; y = 8; w = 2; h = 8; };
        panel.type = "gauge";
        influx.bucket = "profinet";
        influx.filter._measurement = "caparoc";
        influx.filter._field = ["average_current_amps" "average_power_watts"];
        influx.filter.channel = "total";
        influx.fn = "last1";
        panel.fieldConfig.defaults = {
          color.mode = "thresholds";
        };
        panel.options.showThresholdMarkers = false;
        fields.average_current_amps = {
          displayName = "Average Current";
          unit = "amp";
          min = 0;
          max = 30;
          thresholds.steps = [
            { value = null; color = "green"; }
            { value = 25; color = "red"; }
          ];
        };
        fields.average_power_watts = {
          displayName = "Average Power";
          unit = "watt";
          min = 0;
          max = 360;
          thresholds.steps = [
            { value = null; color = "green"; }
            { value = 300; color = "red"; }
          ];
        };
      }
      (channelGraph {
        field = "current_amps";
        integralField = "charge_coulombs";
        filter.channel = "total";
      } {
        panel.gridPos = { x = 2; y = 8; w = 10; h = 8; };
        panel.title = "Workshop Total Current";
        panel.fieldConfig.defaults = {
          unit = "amp";
        };
      })
      (channelGraph {
        field = "power_watts";
        integralField = "energy_joules";
        filter.channel = "total";
      } {
        panel.gridPos = { x = 12; y = 8; w = 10; h = 8; };
        panel.title = "Workshop Total Power";
        panel.fieldConfig.defaults = {
          unit = "watt";
        };
      })
      # System Voltage (TODO: rearrange?)
      (channelGraph {
        field = "voltage_volts";
        integralField = "voltage_time_volt_seconds";
        filter.channel = "total";
      } {
        panel.gridPos = { x = 2; y = 16; w = 10; h = 8; };
        panel.title = "Workshop System Voltage";
        panel.fieldConfig.defaults = {
          unit = "volt";
          decimals = 2;
        };
      })
      # Stacked current/power
      {
        panel.gridPos = { x = 2; y = 24; w = 10; h = 8; };
        panel.title = "Current";
        influx.query = ''
          import "join"

          names = from(bucket: "profinet")
            |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
            |> filter(fn: (r) => r["_measurement"] == "caparoc")
            |> filter(fn: (r) => r["_field"] == "status")
            |> last()
            |> group(columns: ["channel"])
            |> sort(columns: ["_time"])
            |> last()
            |> keep(columns: ["channel", "channel_name"])
            |> map(fn: (r) => ({channel: r.channel, channel_name: if exists r.channel_name then r.channel_name else "Channel "+r.channel}))

          data = from(bucket: "profinet")
            |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
            |> filter(fn: (r) => r["_field"] == "total_charge_coulombs" or r["_field"] == "total_time_seconds")
            |> filter(fn: (r) => r["channel"] != "total")
            |> window(every: v.windowPeriod)
            |> last()
            |> window(every: inf)
            |> difference(nonNegative: true)
            |> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")
            |> map(fn: (r) => ({r with average_current_amps: r.total_charge_coulombs/r.total_time_seconds}))
            |> drop(columns: ["channel_name", "total_charge_coulombs", "total_time_seconds"])

          join.left(
              left: data |> group(columns: ["channel"]),
              right: names,
              on: (l, r) => l.channel == r.channel,
              as: (l, r) => ({l with channel_name: r.channel_name}),
          )
            |> group(columns: ["_measurement", "_field", "_start", "_stop", "name_of_station", "channel", "channel_name"])
            |> yield(name: "mean")
        '';
        panel.fieldConfig.defaults = {
          unit = "amp";
          displayName = "\${__field.labels.channel_name}";
          custom.stacking.mode = "normal";
          custom.fillOpacity = 10;
        };
        panel.options.tooltip.mode = "multi";
        panel.interval = "1s";
      }
      {
        panel.gridPos = { x = 12; y = 24; w = 10; h = 8; };
        panel.title = "Power";
        influx.query = ''
          import "join"

          names = from(bucket: "profinet")
            |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
            |> filter(fn: (r) => r["_measurement"] == "caparoc")
            |> filter(fn: (r) => r["_field"] == "status")
            |> last()
            |> group(columns: ["channel"])
            |> sort(columns: ["_time"])
            |> last()
            |> keep(columns: ["channel", "channel_name"])
            |> map(fn: (r) => ({channel: r.channel, channel_name: if exists r.channel_name then r.channel_name else "Channel "+r.channel}))

          data = from(bucket: "profinet")
            |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
            |> filter(fn: (r) => r["_field"] == "total_energy_joules" or r["_field"] == "total_time_seconds")
            |> filter(fn: (r) => r["channel"] != "total")
            |> window(every: v.windowPeriod)
            |> last()
            |> window(every: inf)
            |> difference(nonNegative: true)
            |> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")
            |> map(fn: (r) => ({r with average_power_watts: r.total_energy_joules/r.total_time_seconds}))
            |> drop(columns: ["channel_name", "total_energy_joules", "total_time_seconds"])

          join.left(
              left: data |> group(columns: ["channel"]),
              right: names,
              on: (l, r) => l.channel == r.channel,
              as: (l, r) => ({l with channel_name: r.channel_name}),
          )
            |> group(columns: ["_measurement", "_field", "_start", "_stop", "name_of_station", "channel", "channel_name"])
            |> yield(name: "mean")
        '';
        panel.fieldConfig.defaults = {
          unit = "watt";
          displayName = "\${__field.labels.channel_name}";
          custom.stacking.mode = "normal";
          custom.fillOpacity = 10;
        };
        panel.options.tooltip.mode = "multi";
        panel.interval = "1s";
      }
      # Per-channel current and power
      (channelGraph {
        field = "current_amps";
        integralField = "charge_coulombs";
        filter.channel = "\${caparoc_channel}";
      } {
        panel.gridPos = { x = 2; y = 32; w = 10; h = 8; };
        panel.title = "\${caparoc_channel} Current";
        panel.fieldConfig.defaults = {
          unit = "amp";
        };
        panel.repeat = "caparoc_channel";
        panel.repeatDirection = "v";
      })
      (channelGraph {
        field = "power_watts";
        integralField = "energy_joules";
        filter.channel = "\${caparoc_channel}";
      } {
        panel.gridPos = { x = 12; y = 32; w = 10; h = 8; };
        panel.title = "\${caparoc_channel} Power";
        panel.fieldConfig.defaults = {
          unit = "watt";
        };
        panel.repeat = "caparoc_channel";
        panel.repeatDirection = "v";
      })
    ];
  };
}
