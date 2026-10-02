{ pkgs, lib, config, ... }:
{
  options.isz.telegraf.amdgpu = lib.mkEnableOption "amdgpu";
  config.services.telegraf.extraConfig = lib.mkIf config.isz.telegraf.amdgpu {
    inputs.execd = [{
      alias = "amdgpu";
      restart_delay = "10s";
      data_format = "influx";
      command = ["${pkgs.amdgpu}/bin/amdgpu"];
      environment = [
        #"RUST_LOG=debug"
      ];
      signal = "STDIN";
    }];
  };
}
