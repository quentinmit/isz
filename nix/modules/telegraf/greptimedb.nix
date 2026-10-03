{ lib, config, pkgs, ... }:
{
  options.isz.telegraf.greptimedb = {
    enable = lib.mkEnableOption "greptimedb output";
  };
  config = lib.mkIf config.isz.telegraf.greptimedb.enable {
    # Telegraf 1.40.0 fixes PRW: https://github.com/influxdata/telegraf/pull/19325
    services.telegraf.package = assert lib.versionOlder pkgs.telegraf.version "1.40.0"; pkgs.unstable.telegraf;
    services.telegraf.extraConfig = {
      outputs.influxdb_v2 = [{
        alias = "greptimedb";
        urls = ["https://greptimedb.isz.wtf/v1/influxdb"];
        token = "telegraf@${config.networking.fqdnOrHostName}:$GREPTIMEDB_PASSWORD";
        ## Leave empty
        organization = "";
        bucket = "telegraf";
        bucket_tag = "greptimedb_database";
        exclude_bucket_tag = true;
        tagexclude = [ "influxdb_bucket" ];
        timeout = "60s";

        tagpass.greptimedb_database = ["*"];
      }];
      outputs.http = [{
        alias = "greptimedb_prometheus";
        url = "https://greptimedb.isz.wtf/v1/prometheus/write?db=prometheus";
        username = "telegraf@${config.networking.fqdnOrHostName}";
        password = "$GREPTIMEDB_PASSWORD";
        data_format = "prometheusremotewrite";
        #log_level = "trace";
        namepass = [ "prometheus" ];
        headers = {
          Content-Type = "application/x-protobuf";
          Content-Encoding = "snappy";
          X-Prometheus-Remote-Write-Version = "0.1.0";
        };
      }];
    };
  };
}
