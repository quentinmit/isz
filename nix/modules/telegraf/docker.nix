{ lib, options, config, pkgs, ... }:
{
  options = with lib; {
    isz.telegraf.docker = mkEnableOption "Docker";
  };
  config = lib.mkIf config.isz.telegraf.docker {
    services.telegraf.extraConfig.inputs.docker = [{
      endpoint = "unix:///var/run/docker.sock";
      gather_services = false;
      container_names = [];
      container_name_include = [];
      container_name_exclude = [];
      timeout = "5s";
      perdevice = true;
      total = false;
      docker_label_include = [];
      docker_label_exclude = [];
    }];
  };
}
