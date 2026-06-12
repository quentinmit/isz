{ lib, options, config, pkgs, ... }:
{
  options = with lib; {
    isz.telegraf.iio.light = mkOption {
      type = types.bool;
      default = config.hardware.sensor.iio.enable or false;
      description = "Whether to monitor an IIO light sensor";
    };
  };
  config = lib.mkMerge [
    {
      services.telegraf.extraConfig = lib.mkIf config.isz.telegraf.iio.light {
        inputs.execd = [{
          alias = "iio";
          name_override = "iio";
          command = [(lib.getExe' pkgs.iio-sensor-proxy "monitor-sensor") "--light"];
          restart_delay = "10s";
          data_format = "grok";
          grok_patterns = [
            ''ambient light sensor \(value: %{NUMBER:light:float}, unit: %{WORD:unit:tag}\)'' # First line
            ''    Light changed: %{NUMBER:light:float} \(%{WORD:unit:tag}\)'' # Subsequent lines
          ];
        }];
      };
    }
    (lib.optionalAttrs (options ? security.polkit) (lib.mkIf config.isz.telegraf.iio.light {
      security.polkit.extraConfig = ''
        polkit.addRule(function(action, subject) {
          if (
            action.id === "net.hadess.SensorProxy.claim-sensor"
            && subject.user === "telegraf"
          ) {
            return polkit.Result.YES;
          }
        });
      '';
    }))
  ];
}
