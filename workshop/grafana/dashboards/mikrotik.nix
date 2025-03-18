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
      }
      {
        panel.title = "Routerboard HW";
        panel.gridPos = { x = 2; y = 1; w = 3; h = 2; };
        panel.type = "stat";
      }
      {
        panel.title = "Installed Packages";
        panel.gridPos = { x = 5; y = 1; w = 5; h = 7; };
        panel.type = "table";
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
        influx.filter._measurement = "snmp-memory-usage";
        influx.filter._field = ["total-memory" "used-memory"];
        influx.filter.hostname = "\${hostname}";
        influx.fn = "last1";
        influx.pivot = true;
        influx.extra = ''
          |> map(fn: (r) => ({
            "memory-name": r["memory-name"],
            _time: r._time,
            _value: float(v: r["used-memory"])/float(v: r["total-memory"])*100.0
          }))
        '';
        # Used RAM memory
        # HDD Utilization
        # TODO: CPU Load
      }
      {
        panel.title = "CPU Load";
        panel.gridPos = { x = 14; y = 1; w = 5; h = 7; };
        influx.filter._measurement = "snmp";
        influx.filter._field = ["cpu-load"];
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
        influx.filter._field = ["cpu-frequency"];
        influx.filter.hostname = "\${hostname}";
        influx.fn = "mean";
        panel.fieldConfig.defaults = {
          unit = "MHz";
        };
      }
    ];
  };
}
