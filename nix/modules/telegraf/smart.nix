{ lib, options, config, pkgs, ... }:
let
  cfg = config.isz.telegraf;
  isNixOS = options ? security.wrappers;
in {
  options = with lib; {
    isz.telegraf = {
      smart.enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable SMART monitoring";
      };
      smart.smartctl = mkOption {
        type = with types; nullOr path;
        default = "${pkgs.smartmontools}/bin/smartctl";
      };
      smart.nvme = mkOption {
        type = with types; nullOr path;
        default = null;
      };
      smart.excludes = mkOption {
        type = types.listOf types.str;
        default = [];
      };
    };
  };
  config = lib.mkMerge [
    (lib.mkIf cfg.smart.enable {
      services.telegraf.extraConfig.inputs.smart = [{
        path_smartctl = lib.mkIf (cfg.smart.smartctl != null) cfg.smart.smartctl;
        path_nvme = lib.mkIf (cfg.smart.nvme != null) cfg.smart.nvme;
        inherit (cfg.smart) excludes;
        attributes = true;
      }];
    })
    (lib.optionalAttrs isNixOS (lib.mkIf (cfg.enable && cfg.smart.enable) {
      isz.telegraf.smart.smartctl = lib.mkDefault "/run/wrappers/bin/smartctl_telegraf";
      isz.telegraf.smart.nvme = lib.mkDefault "/run/wrappers/bin/nvme_telegraf";
      security.wrappers.smartctl_telegraf = lib.mkIf (cfg.smart.smartctl != null) {
        source = "${pkgs.smartmontools}/bin/smartctl";
        owner = "root";
        group = "telegraf";
        permissions = "u+rx,g+x";
        setuid = true;
      };
      security.wrappers.nvme_telegraf = lib.mkIf (cfg.smart.nvme != null) {
        source = "${pkgs.nvme-cli}/bin/nvme";
        owner = "root";
        group = "telegraf";
        permissions = "u+rx,g+x";
        setuid = true;
      };
    }))
  ];
}
