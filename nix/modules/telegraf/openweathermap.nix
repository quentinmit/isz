{ lib, config, ... }:
let
  cfg = config.isz.telegraf;
in {
  options.isz.telegraf.openweathermap = {
    appId = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
    };
    cityIds = lib.mkOption {
      type = with lib.types; listOf str;
      default = [];
    };
  };
  config = {
    isz.telegraf.interval.openweathermap = lib.mkOptionDefault "10m";
    services.telegraf.extraConfig = lib.mkIf (cfg.openweathermap.appId != null && cfg.openweathermap.cityIds != []) {
      inputs.openweathermap = [{
        app_id = cfg.openweathermap.appId;
        city_id = cfg.openweathermap.cityIds;
        lang = "en";
        fetch = ["weather" "forecast"];
        interval = cfg.interval.openweathermap;
      }];
    };
  };
}
