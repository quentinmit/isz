{ config, pkgs, lib, ... }:
with import ../../../nix/modules/isz-grafana/lib.nix { inherit config pkgs lib; };
let
  channelModule = { config, name_of_station, ... }: {
    options.channel = {
      field = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      integralField = lib.mkOption {
        type = lib.types.str;
      };
      filter = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
      };
    };
    config = let
      inherit (config.channel) field integralField filter;
    in lib.mkIf (config.channel.field != null) {
      channel.filter.name_of_station = lib.mkDefault name_of_station;
      spec.data.spec.queries = [{
        spec.query = {
          group = "info8cc-greptimedb-datasource";
          datasource.name = "greptimedb";
          spec.editorType = "sql";
          spec.queryType = "timeseries";
          spec.rawSql = ''
            WITH t1 AS (
              SELECT
                greptime_timestamp as "time",
                last_value(total_time_seconds) RANGE '$__interval' FILL NULL as total_time_seconds,
                last_value(total_${integralField}) RANGE '$__interval' FILL NULL as total_${integralField},
                max(max_${field}) RANGE '$__interval' FILL NULL as max_${field},
                min(min_${field}) RANGE '$__interval' FILL NULL as min_${field}
              FROM
                "profinet"."caparoc"
              WHERE (
                ${lib.concatMapAttrsStringSep " and " (name: value: "${name} = ${sqlValue value}") config.channel.filter}
                and $__timeFilter(greptime_timestamp)
              )
              ALIGN '$__interval' BY (name_of_station, channel)
              ORDER BY time ASC
            )
            SELECT
              time,
              (total_${integralField}-lag(total_${integralField}) over (order by time))/(total_time_seconds-lag(total_time_seconds) over (order by time)) as average_${field},
              max_${field},
              min_${field}
            FROM t1;
          '';
        };
      }];
      spec.vizConfig.group = "timeseries";
      spec.vizConfig.spec.fieldConfig.defaults = {
        custom.fillOpacity = 0;
      };
      spec.vizConfig.spec.options.tooltip.mode = "multi";
      fields."average_${field}" = {
        displayName = "Average";
        color = { mode = "fixed"; fixedColor = "green"; };
        custom.lineWidth = 1;
      };
      fields."max_${field}" = {
        displayName = "Max";
        custom.lineWidth = 0;
        custom.fillOpacity = 25;
        custom.fillBelowTo = "min_${field}";
        color.mode = "fixed";
        custom.hideFrom.legend = true;
      };
      fields."min_${field}" = {
        displayName = "Min";
        custom.lineWidth = 0;
        color.mode = "fixed";
        custom.hideFrom.legend = true;
      };
      spec.data.spec.queryOptions.interval = "1s";
    };
  };
  stackedModule = { config, name_of_station, ... }: {
    options.stacked = {
      field = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      integralField = lib.mkOption {
        type = lib.types.str;
      };
    };
    config = let
      inherit (config.stacked) field integralField;
    in lib.mkIf (config.stacked.field != null) {
      influx = [{
        query = ''
          import "join"

          names = from(bucket: "profinet")
            |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
            |> filter(fn: (r) => r["_measurement"] == "caparoc")
            |> filter(fn: (r) => r["_field"] == "status")
            |> filter(fn: (r) => r.name_of_station == ${fluxValue name_of_station})
            |> last()
            |> group(columns: ["name_of_station", "channel"])
            |> sort(columns: ["_time"])
            |> last()
            |> keep(columns: ["name_of_station", "channel", "channel_name"])
            |> map(fn: (r) => ({name_of_station: r.name_of_station, channel: r.channel, channel_name: if exists r.channel_name then r.channel_name else "Channel "+r.channel}))

          data = from(bucket: "profinet")
            |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
            |> filter(fn: (r) => r["_field"] == "total_${integralField}" or r["_field"] == "total_time_seconds")
            |> filter(fn: (r) => r["channel"] != "total")
            |> filter(fn: (r) => r.name_of_station == ${fluxValue name_of_station})
            |> window(every: v.windowPeriod)
            |> last()
            |> window(every: inf)
            |> difference(nonNegative: true)
            |> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")
            |> map(fn: (r) => ({r with average_${field}: r.total_${integralField}/r.total_time_seconds}))
            |> drop(columns: ["channel_name", "total_${integralField}", "total_time_seconds"])

          join.left(
              left: data |> group(columns: ["name_of_station", "channel"]),
              right: names,
              on: (l, r) => l.name_of_station == r.name_of_station and l.channel == r.channel,
              as: (l, r) => ({l with channel_name: r.channel_name}),
          )
            |> group(columns: ["_measurement", "_field", "_start", "_stop", "name_of_station", "channel", "channel_name"])
            |> yield(name: "mean")
        '';
      }];
      spec.vizConfig.spec.fieldConfig.defaults = {
        displayName = "\${__field.labels.channel_name}";
        custom.stacking.mode = "normal";
        custom.fillOpacity = 10;
      };
      spec.vizConfig.spec.options.tooltip.mode = "multi";
      spec.data.spec.queryOptions.interval = "1s";
    };
  };
  gaugeModule = { config, name_of_station, ... }: {
    options.gauge = {
      fields = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
      };
    };
    config = lib.mkIf (config.gauge.fields != null) {
      spec.vizConfig.group = "gauge";
      spec.data.spec.queries = [{
        spec.query = {
          group = "info8cc-greptimedb-datasource";
          datasource.name = "greptimedb";
          spec.editorType = "sql";
          spec.queryType = "timeseries";
          spec.rawSql = ''
            SELECT
              greptime_timestamp,
              ${lib.concatMapStringsSep ", " (field: "average_${field}") config.gauge.fields}
            FROM
              profinet.caparoc
            WHERE (
              name_of_station = ${sqlValue name_of_station}
              and channel = 'total'
              and $__timeFilter(greptime_timestamp)
            )
            ORDER BY greptime_timestamp DESC
            LIMIT 1;
          '';
        };
      }];
      spec.vizConfig.spec.fieldConfig.defaults = {
        color.mode = lib.mkDefault "palette-classic";
      };
    };
  };
  dashboardModule = { config, ... }: let
    inherit (config) name_of_station;
  in {
    options.name_of_station = lib.mkOption {
      type = lib.types.str;
    };
    options.panels = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
        imports = [
          channelModule
          stackedModule
          gaugeModule
        ];
        _module.args.name_of_station = name_of_station;
      }));
    };
  };
  channelsVar = name_of_station: {
    query = ''
      from(bucket: "profinet")
        |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
        |> filter(fn: (r) => r["_measurement"] == "caparoc")
        |> filter(fn: (r) => r["_field"] == "status")
        |> filter(fn: (r) => r.name_of_station == ${fluxValue name_of_station})
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
    extra.hide = "hideVariable"; # show nothing
    extra.includeAll = true;
    extra.regex = ''/(?<value>\S+)\s+(?<text>.+)/'';
  };
in {
  config.isz.grafana.dashboardsV2."workshop-power" = { config, ... }: {
    imports = [
      dashboardModule
    ];
    config = {
      name_of_station = "workshop-caparoc";
      title = "Workshop Power";
      defaultDatasourceName = "workshop";
      spec.cursorSync = "Tooltip";
      variables = {
        caparoc_channel = channelsVar config.name_of_station;
      };
      layout.kind = "GridLayout";
      layout.spec.items = [
        { spec = {
            element.name = "gauge-volts";
            x = 0; y = 0; width = 2; height = 8;
          }; }
        { spec = {
            element.name = "system-volts";
            x = 2; y = 0; width = 10; height = 8;
          }; }
        { spec = {
            element.name = "battery-temperature";
            x = 12; y = 0; width = 10; height = 8;
          }; }
        { spec = {
            element.name = "gauge-current-power";
            x = 0; y = 8; width = 2; height = 8;
          }; }
        { spec = {
            element.name = "total-current";
            x = 2; y = 8; width = 10; height = 8;
          }; }
        { spec = {
            element.name = "total-power";
            x = 12; y = 8; width = 10; height = 8;
          }; }
        { spec = {
            element.name = "stacked-current";
            x = 2; y = 16; width = 10; height = 8;
          }; }
        { spec = {
            element.name = "stacked-power";
            x = 12; y = 16; width = 10; height = 8;
          }; }
        { spec = {
            element.name = "per-channel-current";
            x = 2; y = 24; width = 10; height = 8;
            repeat.direction = "v";
            repeat.mode = "variable";
            repeat.value = "caparoc_channel";
          }; }
        { spec = {
            element.name = "per-channel-power";
            x = 12; y = 24; width = 10; height = 8;
            repeat.direction = "v";
            repeat.mode = "variable";
            repeat.value = "caparoc_channel";
          }; }
      ];
      # Battery
      panels.gauge-volts = {
        gauge.fields = [ "voltage_volts" ];
        influx = [
          {
            filter._measurement = "epicpwrgate.status";
            filter._field = ["Bat.V" "PS.V"];
            fn = "last1";
          }
        ];
        spec.vizConfig.spec.fieldConfig.defaults = {
          unit = "volt";
          decimals = 1;
          min = 10;
          max = 16;
        };
        fields."Bat.V".displayName = "Battery Voltage";
        fields."PS.V".displayName = "PSU Voltage";
        fields."average_voltage_volts" = {
          displayName = "System Voltage";
          decimals = 2;
        };
      };
      panels.system-volts = {
        channel = {
          field = "voltage_volts";
          integralField = "voltage_time_volt_seconds";
          filter.channel = "total";
        };
        influx = [{
          filter._measurement = "epicpwrgate.status";
          filter._field = ["Bat.V" "PS.V"];
          fn = "mean";
        }];
        spec.title = "Workshop System Voltage";
        spec.vizConfig.spec.fieldConfig.defaults = {
          unit = "volt";
          decimals = 3;
        };
        fields."Bat.V".displayName = "Battery Voltage";
        fields."PS.V".displayName = "PSU Voltage";
      };
      panels.battery-temperature = {
        spec.title = "Battery Temperature";
        influx.filter._measurement = "epicpwrgate.status";
        influx.filter._field = "Temp";
        influx.fn = "mean";
        influx.extra = ''
          |> map(fn: (r) => ({r with _value: (r._value - 32.) * 5./9.}))
        '';
        spec.vizConfig.spec.fieldConfig.defaults = {
          unit = "celsius";
          decimals = 2;
        };
        spec.vizConfig.spec.options.tooltip.mode = "multi";
      };
      # Total Current/Power
      panels.gauge-current-power = {
        gauge.fields = [
          "current_amps"
          "power_watts"
        ];
        spec.vizConfig.spec.fieldConfig.defaults = {
          color.mode = "thresholds";
        };
        spec.vizConfig.spec.options.showThresholdMarkers = false;
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
      };
      panels.total-current = {
        channel = {
          field = "current_amps";
          integralField = "charge_coulombs";
          filter.channel = "total";
        };
        influx = [{
          filter._measurement = "epicpwrgate.status";
          filter._field = ["Bat.A" "TargetI.A"];
          fn = "mean";
        }];
        spec.title = "Workshop Total Current";
        spec.vizConfig.spec.fieldConfig.defaults = {
          unit = "amp";
          decimals = 2;
        };
      };
      panels.total-power = {
        channel = {
          field = "power_watts";
          integralField = "energy_joules";
          filter.channel = "total";
        };
        spec.title = "Workshop Total Power";
        spec.vizConfig.spec.fieldConfig.defaults = {
          unit = "watt";
        };
      };
      # Stacked current/power
      panels.stacked-current = {
        stacked = {
          field = "current_amps";
          integralField = "charge_coulombs";
        };
        spec.title = "Current";
        spec.vizConfig.spec.fieldConfig.defaults = {
          unit = "amp";
        };
      };
      panels.stacked-power = {
        stacked = {
          field = "power_watts";
          integralField = "energy_joules";
        };
        spec.title = "Power";
        spec.vizConfig.spec.fieldConfig.defaults = {
          unit = "watt";
        };
      };
      # Per-channel current and power
      panels.per-channel-current = {
        channel = {
          field = "current_amps";
          integralField = "charge_coulombs";
          filter.channel = "\${caparoc_channel}";
        };
        spec.title = "\${caparoc_channel} Current";
        spec.vizConfig.spec.fieldConfig.defaults = {
          unit = "amp";
        };
      };
      panels.per-channel-power = {
        channel = {
          field = "power_watts";
          integralField = "energy_joules";
          filter.channel = "\${caparoc_channel}";
        };
        spec.title = "\${caparoc_channel} Power";
        spec.vizConfig.spec.fieldConfig.defaults = {
          unit = "watt";
        };
      };
    };
  };
  config.isz.grafana.dashboardsV2."bedroom-power" = { config, ... }: {
    imports = [
      dashboardModule
    ];
    config = {
      name_of_station = "bedroom-caparoc";
      title = "Bedroom Power";
      defaultDatasourceName = "workshop";
      spec.cursorSync = "Tooltip";
      variables = {
        caparoc_channel = channelsVar config.name_of_station;
      };
      layout.kind = "GridLayout";
      layout.spec.items = [
        { spec = {
            element.name = "gauge-volts";
            x = 0; y = 0; width = 2; height = 8;
          }; }
        { spec = {
            element.name = "system-volts";
            x = 2; y = 0; width = 10; height = 8;
          }; }
        { spec = {
            element.name = "battery-temperature";
            x = 12; y = 0; width = 10; height = 8;
          }; }
        { spec = {
            element.name = "gauge-current-power";
            x = 0; y = 8; width = 2; height = 8;
          }; }
        { spec = {
            element.name = "total-current";
            x = 2; y = 8; width = 10; height = 8;
          }; }
        { spec = {
            element.name = "total-power";
            x = 12; y = 8; width = 10; height = 8;
          }; }
        { spec = {
            element.name = "stacked-current";
            x = 2; y = 16; width = 10; height = 8;
          }; }
        { spec = {
            element.name = "stacked-power";
            x = 12; y = 16; width = 10; height = 8;
          }; }
        { spec = {
            element.name = "wago-status";
            x = 2; y = 24; width = 20; height = 11;
          }; }
        { spec = {
            element.name = "per-channel-current";
            x = 2; y = 35; width = 10; height = 8;
            repeat.direction = "v";
            repeat.mode = "variable";
            repeat.value = "caparoc_channel";
          }; }
        { spec = {
            element.name = "per-channel-power";
            x = 12; y = 35; width = 10; height = 8;
            repeat.direction = "v";
            repeat.mode = "variable";
            repeat.value = "caparoc_channel";
          }; }
      ];
      # Battery
      panels.gauge-volts = {
        gauge.fields = [ "voltage_volts" ];
        influx = [
          {
            filter._measurement = "wago.status";
            filter._field = ["BatteryVolts" "PSUVolts"];
            fn = "last1";
          }
        ];
        spec.vizConfig.spec.fieldConfig.defaults = {
          unit = "volt";
          decimals = 1;
          min = 10;
          max = 16;
        };
        fields."BatteryVolts".displayName = "Battery Voltage";
        fields."PSUVolts".displayName = "PSU Voltage";
        fields."average_voltage_volts" = {
          displayName = "System Voltage";
          decimals = 2;
        };
      };
      panels.system-volts = {
        channel = {
          field = "voltage_volts";
          integralField = "voltage_time_volt_seconds";
          filter.channel = "total";
        };
        influx = [{
          filter._measurement = "wago.status";
          filter._field = ["BatteryVolts" "PSUVolts"];
          fn = "mean";
        }];
        spec.title = "Bedroom System Voltage";
        spec.vizConfig.spec.fieldConfig.defaults = {
          unit = "volt";
          decimals = 3;
        };
        fields."BatteryVolts".displayName = "Battery Voltage";
        fields."PSUVolts".displayName = "PSU Voltage";
      };
      panels.battery-temperature = {
        spec.title = "Battery Temperature";
        influx.filter._measurement = "wago.status";
        influx.filter._field = "TemperatureDegreesCelsius";
        influx.fn = "mean";
        spec.vizConfig.spec.fieldConfig.defaults = {
          unit = "celsius";
          decimals = 2;
        };
        spec.vizConfig.spec.options.tooltip.mode = "multi";
      };
      # Total Current/Power
      panels.gauge-current-power = {
        gauge.fields = [
          "current_amps"
          "power_watts"
        ];
        spec.vizConfig.spec.fieldConfig.defaults = {
          color.mode = "thresholds";
        };
        spec.vizConfig.spec.options.showThresholdMarkers = false;
        fields.average_current_amps = {
          displayName = "Average Current";
          unit = "amp";
          min = 0;
          max = 5.5;
          thresholds.steps = [
            { value = null; color = "green"; }
            { value = 5; color = "red"; }
          ];
        };
        fields.average_power_watts = {
          displayName = "Average Power";
          unit = "watt";
          min = 0;
          max = 132;
          thresholds.steps = [
            { value = null; color = "green"; }
            { value = 120; color = "red"; }
          ];
        };
      };
      panels.total-current = {
        channel = {
          field = "current_amps";
          integralField = "charge_coulombs";
          filter.channel = "total";
        };
        influx = [{
          filter._measurement = "wago.status";
          filter._field = ["BatteryInAmps" "BatteryOutAmps" "PSUAmps"];
          fn = "mean";
        }];
        spec.title = "Bedroom Total Current";
        spec.vizConfig.spec.fieldConfig.defaults = {
          unit = "amp";
          decimals = 2;
        };
        fields."BatteryInAmps".displayName = "Battery In";
        fields."BatteryOutAmps".displayName = "Battery Out";
        fields."PSUAmps".displayName = "PSU";
      };
      panels.total-power = {
        channel = {
          field = "power_watts";
          integralField = "energy_joules";
          filter.channel = "total";
        };
        influx = [{
          filter._measurement = "wago.status";
          filter._field = ["PSUAmps" "BatteryOutAmps" "BatteryInAmps" "OutputVolts"];
          fn = null;
          pivot = true;
          extra = ''
            |> map(fn: (r) => ({ r with
              LoadAmps: (r.PSUAmps-r.BatteryInAmps+r.BatteryOutAmps)
            }))
            |> map(fn: (r) => ({ r with LoadWatts: r.OutputVolts * r.LoadAmps }))
            |> keep(columns: ["_time", "LoadWatts"])
            |> aggregateWindow(every: v.windowPeriod, fn: mean, column: "LoadWatts", createEmpty: false)
          '';
        }];
        spec.title = "Bedroom Total Power";
        spec.vizConfig.spec.fieldConfig.defaults = {
          unit = "watt";
        };
      };
      # Stacked current/power
      panels.stacked-current = {
        stacked = {
          field = "current_amps";
          integralField = "charge_coulombs";
        };
        spec.title = "Current";
        spec.vizConfig.spec.fieldConfig.defaults = {
          unit = "amp";
        };
      };
      panels.stacked-power = {
        stacked = {
          field = "power_watts";
          integralField = "energy_joules";
        };
        spec.title = "Power";
        spec.vizConfig.spec.fieldConfig.defaults = {
          unit = "watt";
        };
      };
      # Status
      panels.wago-status = {
        spec.title = "Wago Status";
        spec.vizConfig.group = "state-timeline";
        influx = {
          imports = ["bitwise"];
          filter._measurement = "wago.status";
          filter._field = "Status";
          fn = null;
          extra = ''
            |> duplicate(column: "_value", as: "diff")
            |> difference(columns: ["diff"], keepFirst: true)
            |> filter(fn: (r) => not exists r.diff or r.diff != 0)
            |> map(fn: (r) => ({r with
              ${lib.concatMapStringsSep "\n" (i: ''
                "${lib.fixedWidthNumber 2 i}": bitwise.uand(a: r._value, b: uint(v: 2 ^ ${toString i})) != 0,
              '') (lib.range 0 15)}
            }))
            |> drop(columns: ["_value", "diff", "_start", "_stop", "_field", "host"])
          '';
        };
        fields."02".displayName = "Buffer mode";
        fields."08".displayName = "Battery charge <85%";
      };
      # Per-channel current and power
      panels.per-channel-current = {
        channel = {
          field = "current_amps";
          integralField = "charge_coulombs";
          filter.channel = "\${caparoc_channel}";
        };
        spec.title = "\${caparoc_channel} Current";
        spec.vizConfig.spec.fieldConfig.defaults = {
          unit = "amp";
        };
      };
      panels.per-channel-power = {
        channel = {
          field = "power_watts";
          integralField = "energy_joules";
          filter.channel = "\${caparoc_channel}";
        };
        spec.title = "\${caparoc_channel} Power";
        spec.vizConfig.spec.fieldConfig.defaults = {
          unit = "watt";
        };
      };
    };
  };
}
