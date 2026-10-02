{ lib, config, ... }:
{
  options.isz.telegraf.influxdb = {
    namedrop = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
    };
  };
  config.services.telegraf.extraConfig = let
    cfg = config.isz.telegraf.influxdb;
  in {
    processors.starlark = [{
      alias = "dropnan";
      order = 9999; # Run last
      # Work around https://github.com/influxdata/telegraf/issues/17205
      # The influxdb_v2 output drops an entire batch of metrics if there is a NaN value in any of them.
      source = ''
        load("logging.star", "log")
        nan = float('nan')

        def apply(metric):
          for k, v in metric.fields.items():
            if v == nan:
              metric.fields.pop(k)
              log.warn("Dropped NaN value: metric {} field {}".format(metric.name, k))
          return metric
        '';
    }];
    outputs = {
      influxdb_v2 = [{
        # TODO: Disable https for some hosts
        urls = ["https://influx.isz.wtf"];
        token = "$INFLUX_TOKEN";
        organization = "icestationzebra";
        bucket = "icestationzebra";
        bucket_tag = "influxdb_bucket";
        exclude_bucket_tag = true;
        tagexclude = [ "greptimedb_database" ];
        tagdrop.influxdb_bucket = [""];
        timeout = "60s"; # Default timeout of 5s is sometimes too slow
        inherit (cfg) namedrop;
      }];
      # TODO: Add option for stdout
    };
  };
}
