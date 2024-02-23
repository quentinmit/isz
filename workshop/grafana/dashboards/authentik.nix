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
    # Based on https://grafana.com/grafana/dashboards/14837-authentik/
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
            unit = "s";
          };
        }
        {
          panel = {
            title = "Task status";
            gridPos = { x = 17; y = 1; w = 3; h = 6; };
            type = "piechart";
          };
          influx.filter._measurement = "prometheus";
          influx.filter._field = "authentik_system_tasks";
          influx.fn = "last1";
          influx.groupBy = [
            { fn = "last"; fields = ["task_name"]; }
            { fn = "count"; fields = ["status"]; }
          ];
          panel.options.pieType = "donut";
          panel.fieldConfig.defaults = {
            displayName = "\${__field.labels.status}";
          };
          fields.successful.color = {
            mode = "fixed";
            fixedColor = "green";
          };
          fields.error.color = {
            mode = "fixed";
            fixedColor = "red";
          };
          fields.unknown.color = {
            mode = "fixed";
            fixedColor = null;
          };
        }
        {
          panel = {
            title = "Cached policies";
            gridPos = { x = 17; y = 7; w = 3; h = 6; };
            type = "piechart";
          };
          influx = [
            {
              filter._measurement = "prometheus";
              filter._field = "authentik_policies_cached";
              fn = "last1";
              groupBy.fn = "sum";
            }
            # sum(authentik_models{namespace=~"$namespace",app="authentik_policies", model_name="policy"}) - authentik_policies_cached
          ];
          panel.options.pieType = "donut";
          fields."authentik_policies_cached" = {
            displayName = "Cached policies";
          };
        }
        {
          panel = {
            title = "Connected Workers";
            gridPos = { x = 20; y = 6; w = 4; h = 3; };
            type = "stat";
          };
          influx.filter._measurement = "prometheus";
          influx.filter._field = "authentik_admin_workers";
          influx.fn = "last";
          influx.groupBy.fn = "max";
          panel.fieldConfig.defaults.mappings = [{
            type = "value";
            options."0".text = "None";
          }];
        }
        {
          panel = {
            title = "Connected Outposts";
            gridPos = { x = 20; y = 6; w = 4; h = 3; };
            type = "stat";
          };
          influx.filter._measurement = "prometheus";
          influx.filter._field = "authentik_outposts_connected";
          influx.fn = "last";
          influx.groupBy.fn = "sum";
          panel.fieldConfig.defaults.mappings = [{
            type = "value";
            options."0".text = "None";
          }];
        }
        {
          panel = {
            title = "System task duration";
            gridPos = { x = 0; y = 13; w = 4; h = 16; };
            type = "bargauge";
          };
          influx.filter._measurement = "prometheus";
          influx.filter._field = "authentik_system_tasks";
          influx.fn = "last1";
          influx.groupBy = {
            fields = ["task_name"];
            fn = "mean";
          };
          panel.fieldConfig.defaults = {
            color.mode = "thresholds";
            thresholds.mode = "absolute";
            thresholds.steps = [
              { value = null; color = "green"; }
              { value = 800000; color = "red"; }
            ];
            unit = "s";
            displayName = "\${__field.labels.task_name}";
          };
          panel.options = {
            displayMode = "lcd";
            orientation = "horizontal";
          };
        }
      ];
  };
}
