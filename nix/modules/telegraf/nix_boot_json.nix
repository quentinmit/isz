{ lib, config, options, ... }:
let
  cfg = config.isz.telegraf.nix;
  interval = config.isz.telegraf.interval.nix;
  isNixOS = options ? security.wrappers;
in {
  options = with lib; {
    isz.telegraf.nix.bootJson = mkEnableOption "NixOS boot.json";
  };
  config = {
    isz.telegraf.nix.bootJson = lib.mkIf isNixOS true;
    services.telegraf.extraConfig = lib.mkIf cfg.bootJson {
      inputs.file = [{
        alias = "nix_boot_json";
        inherit interval;
        files = [
          "/run/current-system/boot.json"
          "/run/booted-system/boot.json"
        ];
        file_path_tag = "boot_json_path";
        data_format = "xpath_json";
        xpath_native_types = true;
        xpath = [{
          metric_name = "'nix_boot_json'";
          fields.kernel = "//org.nixos.bootspec.v1/kernel";
          fields.kernel_derivation_hash = ''substring-before(substring-after(//org.nixos.bootspec.v1/kernel, "/nix/store/"), "-")'';
          fields.kernel_derivation_name = ''substring-before(substring-after(//org.nixos.bootspec.v1/kernel, "-"), "/")'';
          fields.label = "//org.nixos.bootspec.v1/label";
          fields.toplevel = "//org.nixos.bootspec.v1/toplevel";
        }];
      }];
    };
  };
}
