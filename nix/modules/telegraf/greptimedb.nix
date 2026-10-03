{ lib, config, ... }:
{
  options.isz.telegraf.greptimedb = {
    enable = lib.mkEnableOption "greptimedb output";
  };
  config = lib.mkIf config.isz.telegraf.greptimedb.enable {
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
    };
  };
}
