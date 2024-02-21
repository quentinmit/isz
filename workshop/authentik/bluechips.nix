{ config, lib, pkgs, ... }:
{
  systemd.services.bluechips.environment.ROCKET_AUTHENTIK_USE_HEADERS = "true";
  services.authentik.apps.bluechips = {
    name = "BlueChips";
    type = "proxy";
    properties = [
      "email"
      "openid"
      "profile"
      "ak_proxy"
    ];
    provider.attrs.external_host = "https://bluechips.isz.wtf";
  };
  services.nginx.virtualHosts."bluechips.isz.wtf" = {
    locations."/".extraConfig = ''
      auth_request     /outpost.goauthentik.io/auth/nginx;
      error_page       401 = @goauthentik_proxy_signin;
      auth_request_set $auth_cookie $upstream_http_set_cookie;
      add_header       Set-Cookie $auth_cookie;

      # translate headers from the outposts back to the actual upstream
      auth_request_set $authentik_username $upstream_http_x_authentik_username;
      auth_request_set $authentik_groups $upstream_http_x_authentik_groups;
      auth_request_set $authentik_email $upstream_http_x_authentik_email;
      auth_request_set $authentik_name $upstream_http_x_authentik_name;
      auth_request_set $authentik_uid $upstream_http_x_authentik_uid;

      proxy_set_header X-authentik-username $authentik_username;
      proxy_set_header X-authentik-groups $authentik_groups;
      proxy_set_header X-authentik-email $authentik_email;
      proxy_set_header X-authentik-name $authentik_name;
      proxy_set_header X-authentik-uid $authentik_uid;
    '';
    locations."/outpost.goauthentik.io" = {
      inherit (config.services.nginx.virtualHosts."${config.services.authentik.nginx.host}".locations."/") proxyPass;
      extraConfig = ''
        proxy_set_header        X-Original-URL $scheme://$http_host$request_uri;
        add_header              Set-Cookie $auth_cookie;
        auth_request_set        $auth_cookie $upstream_http_set_cookie;
        proxy_pass_request_body off;
        proxy_set_header        Content-Length "";
      '';
    };
    locations."@goauthentik_proxy_signin".extraConfig = ''
      internal;
      add_header Set-Cookie $auth_cookie;
      return 302 /outpost.goauthentik.io/start?rd=$request_uri;
      # For domain level, use the below error_page to redirect to your authentik server with the full redirect path
      #return 302 https://auth.isz.wtf/outpost.goauthentik.io/start?rd=$scheme://$http_host$request_uri;
    '';
  };
}
