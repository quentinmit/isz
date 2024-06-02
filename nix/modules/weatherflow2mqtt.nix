{ lib, pkgs, config, options, ... }:
let
  cfg = config.services.weatherflow2mqtt;
in {
  options = with lib; {
    services.weatherflow2mqtt = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = ''
          Run a weatherflow2mqtt server
        '';
      };
      user = mkOption {
        type = types.str;
        default = "weatherflow2mqtt";
      };
      debug = mkEnableOption ''Show debugging output'';
      tz = mkOption {
        default = config.time.timeZone;
        defaultText = literalExpression "config.time.timeZone";
        type = types.addCheck types.str (str: filter (c: c == " ") (stringToCharacters str) == [])
               // { description = "string without spaces"; };
        description = ''Set your local Timezone.'';
      };
      unitSystem = mkOption {
        default = "metric";
        type = types.enum ["metric" "imperial"];
        description = ''Enter imperial or metric. This will determine the unit system used when displaying the values.'';
      };
      language = mkOption {
        default = "en";
        type = types.enum ["en" "da" "de" "fr" "nl" "se"];
        description = ''Use this to set the language for Wind Direction cardinals and other sensors with text strings as state value. These strings will then be displayed in HA in the selected language.'';
      };
      rapidWindInterval = mkOption {
        default = 0;
        type = types.int;
        description = ''The weather stations delivers wind speed and bearing every 2 seconds. If you don't want to update the HA sensors so often, you can set a number here (in seconds), for how often they are updated.'';
      };
      elevation = mkOption {
        default = 0;
        type = types.float;
        description = ''Set the hight above sea level for where the station is placed. This is used when calculating some of the sensor values. Station elevation plus Device height above ground. The value has to be in meters.'';
      };
      latitude = mkOption {
        default = 0.0;
        type = types.float;
        description = ''Set the Latitude where the Station is located.'';
      };
      longitude = mkOption {
        default = 0.0;
        type = types.float;
        description = ''Set the Longitude where the Station is located.'';
      };
      zambrettiMinPressure = mkOption {
        default = null;
        type = types.nullOr types.float;
        description = ''All Time Low Sea Level Pressure. Default is 960 (Mb for Metric) or Default is 28.35 (inHG for Imperial)'';
      };
      zambrettiMaxPressure = mkOption {
        default = null;
        type = types.nullOr types.float;
        description = ''All Time High Sea Level Pressure. Default is 1060 (Mb for Metric) or Default is 31.30 (inHG for Imperial)'';
      };
      weatherflow.host = mkOption {
        default = "0.0.0.0";
        type = types.str;
        description = ''Unless you have a very special IP setup or the Weatherflow hub is on a different network, you should not change this.'';
      };
      weatherflow.port = mkOption {
        default = 50222;
        type = types.port;
        description = ''Weatherflow always broadcasts on port 50222/udp, so don't change this.'';
      };
      mqtt.host = mkOption {
        default = "127.0.0.1";
        type = types.str;
        description = ''The IP address of your mqtt server.'';
      };
      mqtt.port = mkOption {
        default = 1883;
        type = types.port;
        description = ''The Port for your mqtt server. Default value is 1883'';
      };
      mqtt.username = mkOption {
        default = "";
        type = types.str;
        description = ''The username used to connect to the mqtt server. Leave blank to use Anonymous connection.'';
      };
      mqtt.password = mkOption {
        default = "";
        type = types.str;
        description = ''The password used to connect to the mqtt server. Leave blank to use Anonymous connection.'';
      };
      mqtt.debug = mkEnableOption ''Set this to True, to get some more mqtt debugging messages in the Container log file.'';
      station.id = mkOption {
        default = null;
        type = types.nullOr types.int;
        description = ''Enter your Station ID for your WeatherFlow Station. The correct station.id is the number that you see when you access your Station from the Tempest Web APP. For example when you are on https://tempestwx.com/station/XXXXX/'';
      };
      station.token = mkOption {
        default = "";
        type = types.str;
        description = ''Enter your personal access Token to allow retrieval of data. If you don't have the token login with your account and create the token. NOTE You must own a WeatherFlow station to get this token.'';
      };
      station.tokenPath = mkOption {
        default = null;
        type = types.nullOr types.path;
        description = "Path to file containing a personal access token.";
      };
      forecastInterval = mkOption {
        default = 30;
        type = types.int;
        description = ''The interval in minutes, between updates of the Forecast data.'';
      };
    };
  };
  config = lib.mkIf cfg.enable {
    users.extraUsers.${cfg.user} = {
      isSystemUser = true;
      group = cfg.user;
    };
    users.extraGroups.${cfg.user} = {};
    systemd.services.weatherflow2mqtt = {
      description = "WeatherFlow2MQTT daemon";
      wants = [ "network-online.target" "mosquitto.service" ];
      after = [ "network-online.target" "mosquitto.service" ];
      wantedBy = [ "multi-user.target" ];
      script = lib.optionalString (cfg.station.tokenPath != null) ''
        export STATION_TOKEN="$(cat ${lib.escapeShellArg cfg.station.tokenPath})"
      '' + ''
        exec ${pkgs.weatherflow2mqtt}/bin/weatherflow2mqtt
      '';
      serviceConfig = {
        Restart = "always";
        RestartSec = "5s";
        User = cfg.user;
        Group = cfg.user;
        StateDirectory = "weatherflow2mqtt";
        WorkingDirectory = "%S/weatherflow2mqtt";
      };
      environment = {
        EXTERNAL_DIRECTORY = "%S/weatherflow2mqtt";
        DEBUG = if cfg.debug then "1" else "0";
        TZ = cfg.tz;
        UNIT_SYSTEM = cfg.unitSystem;
        LANGUAGE = cfg.language;
        RAPID_WIND_INTERVAL = builtins.toString cfg.rapidWindInterval;
        ELEVATION = builtins.toString cfg.elevation;
        LATITUDE = builtins.toString cfg.latitude;
        LONGITUDE = builtins.toString cfg.longitude;
        ZAMBRETTI_MIN_PRESSURE = if cfg.zambrettiMinPressure == null then null else builtins.toString cfg.zambrettiMinPressure;
        ZAMBRETTI_MAX_PRESSURE = if cfg.zambrettiMaxPressure == null then null else builtins.toString cfg.zambrettiMaxPressure;
        WF_HOST = cfg.weatherflow.host;
        WF_PORT = builtins.toString cfg.weatherflow.port;
        MQTT_HOST = cfg.mqtt.host;
        MQTT_PORT = builtins.toString cfg.mqtt.port;
        MQTT_USERNAME = cfg.mqtt.username;
        MQTT_PASSWORD = cfg.mqtt.password;
        MQTT_DEBUG = if cfg.mqtt.debug then "1" else "0";
        STATION_ID = builtins.toString cfg.station.id;
        STATION_TOKEN = cfg.station.token;
        FORECAST_INTERVAL = builtins.toString cfg.forecastInterval;
      };
    };
  };
}
