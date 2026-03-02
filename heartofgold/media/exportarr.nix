{ config, lib, pkgs, ... }:
{
  config = lib.mkMerge ((lib.imap (i: name: {
    sops.secrets."${name}/apikey" = {};
    services.prometheus.exporters."exportarr-${name}" = {
      enable = true;
      port = 9700+i;
      url = "http://localhost:${toString config.services.${name}.settings.server.port}/${name}";
      apiKeyFile = config.sops.secrets."${name}/apikey".path;
    };
    systemd.services."prometheus-exportarr-${name}-exporter".serviceConfig.NFTSet = ["cgroup:inet:arr:cg_arr"];
    isz.telegraf.prometheus.apps."exportarr-${name}".url = "http://localhost:${toString config.services.prometheus.exporters."exportarr-${name}".port}/metrics";
  }) [
    "sonarr"
    "prowlarr"
  ]) ++ [{
    systemd.services.telegraf.serviceConfig.NFTSet = ["cgroup:inet:arr:cg_nginx"];
  }]);
}
