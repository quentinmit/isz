{ config, lib, pkgs, ... }:
{
  options.isz.quentin.ai.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.isz.quentin.enable;
  };

  config = lib.mkIf config.isz.quentin.ai.enable {
    home.packages = with pkgs; [
      unstable.mcp-grafana
      unstable.greptimedb-mcp-server
      unstable.antigravity-cli
    ];
  };
}