{ config, ... }:
{
  config.isz.grafana.dashboardsV2.ping-times = {
    title = "Ping Times";
    defaultDatasourceName = "workshop";
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
    };
  };
}
