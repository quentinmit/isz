{ config, lib, pkgs, ... }:
{
  services.authentik.apps.loki = {
    name = "Loki";
    type = "proxy";
    host = "loki.isz.wtf";
    nginx = true;
    properties = [
      "email"
      "openid"
      "profile"
      "ak_proxy"
    ];
  };
}
