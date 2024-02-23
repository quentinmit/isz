{ config, lib, pkgs, ... }:
{
  services.paperless.extraConfig = {
    PAPERLESS_ENABLE_HTTP_REMOTE_USER = true;
    PAPERLESS_HTTP_REMOTE_USER_HEADER_NAME = "HTTP_X_AUTHENTIK_USERNAME";
  };

  services.authentik.apps.paperless = {
    name = "Paperless";
    type = "proxy";
    host = "paperless.isz.wtf";
    nginx = true;
    properties = [
      "email"
      "openid"
      "profile"
      "ak_proxy"
    ];
  };
}