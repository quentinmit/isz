{ config, lib, pkgs, ... }:
{
  systemd.services.bluechips.environment.ROCKET_AUTHENTIK_USE_HEADERS = "true";
  services.authentik.apps.bluechips = {
    name = "BlueChips";
    type = "proxy";
    host = "bluechips.isz.wtf";
    nginx = true;
  };
}
