{ config, pkgs, lib, ... }:
{
  services.flaresolverr = {
    enable = true;
  };
  systemd.services.flaresolverr.serviceConfig.NFTSet = ["cgroup:inet:arr:cg_arr"];
}
