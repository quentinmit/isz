{ config, ... }:
{
  config.isz.grafana.dashboardsV2."Experimental/nixos" = {
    title = "NixOS";
    defaultDatasourceName = "workshop";
    panels.last-updated = {
      influx.query = ''
        import "join"
        import "strings"

        registry = from(bucket: "icestationzebra")
          |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
          |> filter(fn: (r) => r["_measurement"] == "nix_registry")
          |> filter(fn: (r) => r["_field"] == "lastModified")
          |> last()
          |> map(fn: (r) => ({r with _value: r._value * 1000., _field: strings.split(v: r.registry_path, t: "/")[2]}))
          |> keep(columns: ["_time", "host", "_field", "_value"])
          |> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")
          |> group()

        kernel = from(bucket: "icestationzebra")
          |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
          |> filter(fn: (r) => r["_measurement"] == "sysctl")
          |> filter(fn: (r) => r["_field"] == "kernel.osrelease")
          |> last()
          |> group()

        join.full(
          left: registry,
          right: kernel,
          on: (l, r) => l.host == r.host,
          as: (l, r) => ({l with "booted-osrelease": r._value})
        )
          |> yield(name: "last")
      '';
      spec.title = "isz lastUpdated";
      spec.vizConfig = {
        group = "table";
        #spec.options.showHeader = true;
        spec.fieldConfig.defaults = {
          unit = "dateTimeAsSystem";
        };
      };
    };
  };
}
