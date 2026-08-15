{ lib, options, config, pkgs, ... }:
let
  cfg = config.isz.telegraf;
in {
  options = with lib; {
    isz.telegraf = {
      prometheus.apps = let
        interval = config.isz.telegraf.interval.prometheus;
        app = with types; submodule ({ name, config, ... }: {
          options = {
            url = mkOption { type = str; };
            tags = mkOption { type = attrsOf str; };
            extraConfig = mkOption { type = attrs; };
          };
          config = {
            tags.app = lib.mkDefault name;
            extraConfig = {
              alias = name;
              urls = [config.url];
              metric_version = 2;
              inherit interval;
              inherit (config) tags;
            };
          };
        });
      in mkOption {
        type = with types; attrsOf app;
        default = {};
      };
    };
  };
  config = {
    isz.telegraf.interval.prometheus = lib.mkOptionDefault "60s";
    services.telegraf.extraConfig.inputs.prometheus = lib.mkIf (cfg.prometheus.apps != {}) (lib.mapAttrsToList (_: value: value.extraConfig) cfg.prometheus.apps);
  };
}
