{ lib, config, options, ... }:
let
  cfg = config.isz.telegraf.nix;
  interval = config.isz.telegraf.interval.nix;
  isNixOS = options ? security.wrappers;
in {
  options = with lib; {
    isz.telegraf.nix.registry = mkEnableOption "NixOS registry";
  };
  config = {
    isz.telegraf.interval.nix = lib.mkOptionDefault "60s";
    isz.telegraf.nix.registry = lib.mkIf isNixOS true;
    services.telegraf.extraConfig = lib.mkIf cfg.registry {
      inputs.file = [{
        alias = "nix_registry";
        inherit interval;
        files = [
          "/run/current-system/etc/nix/registry.json"
          "/run/booted-system/etc/nix/registry.json"
        ];
        file_path_tag = "registry_path";
        data_format = "xpath_json";
        xpath_native_types = true;
        xpath = [{
          metric_name = "'nix_registry'";
          metric_selection = "//flakes/*";
          tag_selection = "from/*";
          field_selection = "to/*";
        }];
      }];
    };
  };
}
