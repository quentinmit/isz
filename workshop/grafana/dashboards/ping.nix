{ config, ... }:
{
  config.isz.grafana.dashboardsV2."Experimental/ping-times" = {
    title = "Ping Times";
    defaultDatasourceName = "workshop";
    variables.country = {
      influx.predicate = ''r._measurement == "ping"'';
      spec.multi = false;
      spec.includeAll = false;
    };
    panels.by-target = {
      influx.filter = {
        _measurement = "ping";
        _field = "average_response_ms";
        country = "\${country}";
      };
      influx.groupBy = {
        fn = "max";
        fields = [
          "_measurement"
          "_field"
          "city"
          "country"
          "datacenter"
          "url"
        ];
      };
      influx.fn = "max";
      spec.title = "Max Ping Time by Target";
      spec.vizConfig.spec.fieldConfig.defaults = {
        displayName = "\${__field.labels.url} - \${__field.labels.city}, \${__field.labels.country} - \${__field.labels.datacenter}";
        unit = "ms";
      };
    };
  };
}
