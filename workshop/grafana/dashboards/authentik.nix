{ config, options, pkgs, lib, ... }:
{
  config.isz.grafana.dashboards.authentik = {
    uid = "authentik";
    title = "authentik";
    defaultDatasourceName = "workshop";
    variables = {
      namespace = {
        predicate = ''r["_measurement"] == "prometheus" and r["_field"] == "authentik_outpost_connection"'';
        extra.label = "Namespace";
      };
    };
    panels = let
      interval = config.isz.telegraf.interval.prometheus;
      in [
        {
          panel = {
            gridPos = { x = 0; y = 0; w = 24; h = 1; };
            title = "authentik Core";
            type = "row";
          };
        }
        {
          panel = {
            title = "FlowPlanner time by flow";
            gridPos = { x = 0; y = 1; h = 12; w = 17; };
            inherit interval;
          };
          influx.filter._measurement = "prometheus";
          influx.filter._field = ["authentik_flows_plan_time_sum" "authentik_flows_plan_time_count"];
          influx.fn = "derivative";
          influx.groupBy.fields = ["flow_slug"];
          influx.pivot = true;
          influx.extra = ''
            |> map(fn: (r) => ({flow_slug: r.flow_slug, _time: r._time, _value: r.authentik_flows_plan_time_sum/r.authentik_flows_plan_time_count}))
          '';
          panel.fieldConfig.defaults = {
            unit = "ms";
          };
        }
      ];
  };
}
