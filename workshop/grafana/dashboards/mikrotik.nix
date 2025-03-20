{ config, pkgs, lib, ... }:
with import ../../../nix/modules/isz-grafana/lib.nix { inherit config pkgs lib; };
{
  config.isz.grafana.dashboards.Mikrotik = {
    uid = "mikrotik";
    title = "Mikrotik";
    defaultDatasourceName = "workshop";
    graphTooltip = 2;
    variables.hostname = {
      predicate = ''r["_measurement"] == "mikrotik-/interface"'';
      extra.label = "Host";
    };
    panels = [
      {
        panel.title = "System";
        panel.type = "row";
        panel.gridPos = { x = 0; y = 0; w = 24; h = 1; };
      }
      {
        panel.title = "Identity";
        panel.gridPos = { x = 0; y = 1; w = 2; h = 3; };
        panel.type = "stat";
        # TODO
      }
      {
        panel.title = "Routerboard HW";
        panel.gridPos = { x = 2; y = 1; w = 3; h = 2; };
        panel.type = "stat";
        # TODO
      }
      {
        panel.title = "Installed Packages";
        panel.gridPos = { x = 5; y = 1; w = 5; h = 7; };
        panel.type = "table";
        # TODO
      }
      {
        panel.gridPos = { x = 10; y = 1; w = 4; h = 7; };
        panel.type = "bargauge";
        panel.fieldConfig.defaults = {
          decimals = 1;
          max = 100;
          min = 0;
          unit = "percent";
          color.mode = "thresholds";
          thresholds.steps = [
            { value = null; color = "rgba(50, 172, 45, 0.97)"; }
            { value = 70; color = "rgba(237, 129, 40, 0.89)"; }
            { value = 90; color = "rgba(245, 54, 54, 0.9)"; }
          ];
        };
        panel.options = {
          displayMode = "lcd";
        };
        influx = [
          {
            filter._measurement = "snmp-memory-usage";
            filter._field = ["total-memory" "used-memory"];
            filter.hostname = "\${hostname}";
            fn = "last1";
            pivot = true;
            extra = ''
              |> map(fn: (r) => ({
                "memory-name": r["memory-name"],
                _time: r._time,
                _value: float(v: r["used-memory"])/float(v: r["total-memory"])*100.0
              }))
            '';
          }
          {
            filter._measurement = "snmp";
            filter._field = "cpu-load";
            filter.hostname = "\${hostname}";
            fn = "last1";
            groupBy.fn = "mean";
          }
        ];
        # Used RAM memory
        # HDD Utilization
        # TODO: CPU Load
      }
      {
        panel.title = "CPU Load";
        panel.gridPos = { x = 14; y = 1; w = 5; h = 7; };
        influx.filter._measurement = "snmp";
        influx.filter._field = "cpu-load";
        influx.filter.hostname = "\${hostname}";
        influx.fn = "mean";
        panel.fieldConfig.defaults = {
          unit = "percent";
        };
      }
      {
        panel.title = "CPU Frequency";
        panel.gridPos = { x = 19; y = 1; w = 5; h = 7; };
        influx.filter._measurement = "snmp";
        influx.filter._field = "cpu-frequency";
        influx.filter.hostname = "\${hostname}";
        influx.fn = "mean";
        panel.fieldConfig.defaults = {
          unit = "MHz";
        };
      }
      {
        panel.title = "CPU";
        panel.gridPos = { x = 2; y = 3; w = 3; h = 2; };
        panel.type = "stat";
        # TODO
      }
      {
        panel.title = "Temperature";
        panel.gridPos = { x = 0; y = 4; w = 2; h = 6; };
        panel.type = "gauge";
        influx.filter._measurement = "snmp-mikrotik-gauges";
        influx.filter.unit = "celsius";
        influx.filter.hostname = "\${hostname}";
        influx.fn = "last1";
        influx.groupBy = {
          fields = [];
          fn = "max1";
        };
        panel.fieldConfig.defaults = {
          unit = "celsius";
          min = 0;
          max = 100;
          color.mode = "thresholds";
          thresholds.steps = [
            { value = null; color = "blue"; }
            { value = 30; color = "green"; }
            { value = 60; color = "yellow"; }
            { value = 70; color = "orange"; }
            { value = 80; color = "red"; }
          ];
        };
      }
      {
        panel.title = "System version";
        panel.gridPos = { x = 2; y = 5; w = 3; h = 3; };
        panel.type = "stat";
        # TODO
      }
      {
        panel.title = "Uptime";
        panel.gridPos = { x = 2; y = 8; w = 3; h = 2; };
        panel.type = "stat";
        influx.filter._measurement = "snmp";
        influx.filter._field = "uptime";
        influx.filter.hostname = "\${hostname}";
        influx.fn = "last1";
        influx.extra = ''
          |> map(fn: (r) => ({r with _value: float(v: r._value)/100.0}))
        '';
        panel.fieldConfig.defaults = {
          unit = "dtdurations";
        };
      }
      {
        panel.title = "Active Users";
        panel.gridPos = { x = 5; y = 8; w = 9; h = 7; };
        panel.type = "table";
        # TODO
      }
      {
        panel.title = "Memory Utilization";
        panel.gridPos = { x = 14; y = 9; w = 10; h = 7; };
        panel.fieldConfig.defaults = {
          unit = "decbytes";
        };
        influx.filter._measurement = "snmp-memory-usage";
        influx.filter._field = ["total-memory" "used-memory"];
        influx.filter.memory-name = "main memory";
        influx.filter.hostname = "\${hostname}";
        influx.fn = "mean";

        fields."total-memory" = {
          color.fixedColor = "#E24D42";
          color.mode = "fixed";
          custom.fillOpacity = 20;
          custom.lineWidth = 0;
        };
        fields."used-memory" = {
          color.fixedColor = "#1F78C1";
          color.mode = "fixed";
        };
      }
      {
        panel.title = "Voltage";
        panel.gridPos = { x = 0; y = 10; w = 2; h = 2; };
        panel.type = "stat";
        panel.fieldConfig.defaults = {
          unit = "volt";
        };
        influx.filter._measurement = "snmp";
        influx.filter._field = "voltage";
        influx.filter.hostname = "\${hostname}";
        influx.fn = "last1";
      }
      {
        panel.title = "IP Address";
        panel.gridPos = { x = 2; y = 10; w = 3; h = 2; };
        panel.type = "stat";
        panel.fieldConfig.defaults = {
          displayName = "\${__field.labels.interface}";
        };
        panel.options.fields = "/.*/";
        influx.filter._measurement = "mikrotik-/ip/address";
        influx.filter._field = "address";
        influx.filter.disabled = "false";
        influx.filter.hostname = "\${hostname}";
        influx.fn = "last1";
        influx.extra = ''
          |> keep(columns: ["interface", "_value"])
        '';
      }
      {
        panel.title = "Public Address";
        panel.gridPos = { x = 0; y = 12; w = 5; h = 3; };
        panel.type = "stat";
        panel.fieldConfig.defaults = {
          displayName = "\${__field.labels.interface}";
        };
        panel.options.fields = "/.*/";
        influx.filter._measurement = "mikrotik-/ip/address";
        influx.filter._field = "address";
        influx.filter.disabled = "false";
        influx.filter.hostname = "\${hostname}";
        influx.fn = "last1";
        influx.extra = ''
          |> keep(columns: ["interface", "_value"])
        '';
      }

      {
        panel.title = "DHCP";
        panel.gridPos = { x = 0; y = 15; w = 24; h = 1; };
        panel.type = "row";
      }
      {
        panel.title = "IP Pool Usage";
        panel.gridPos = { x = 0; y = 16; w = 5; h = 8; };
        panel.type = "bargauge";
        panel.fieldConfig.defaults = {
          color.mode = "thresholds";
          thresholds.mode = "percentage";
          thresholds.steps = [
            { value = null; color = "green"; }
            { value = 80; color = "yellow"; }
            { value = 90; color = "red"; }
          ];
        };
        panel.options = {
          displayMode = "lcd";
          orientation = "horizontal";
        };
        influx.filter._measurement = "mikrotik-/ip/pool";
        influx.filter._field = ["total" "used"];
        influx.filter.hostname = "\${hostname}";
        influx.fn = "last1";
        influx.pivot = true;
        influx.extra = ''
          |> keep(columns: ["name", "total", "used"])
          |> group()
        '';
        panel.transformations = [{
          id = "rowsToFields";
          options.mappings = [
            { fieldName = "name"; handlerKey = "field.name"; }
            { fieldName = "total"; handlerKey = "max"; }
            { fieldName = "used"; handlerKey = "field.value"; }
          ];
        }];
      }
    ];
  };
}
