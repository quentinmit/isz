{ config, lib, ... }:
let
  defaultAuthentikURL = config.services.nginx.virtualHosts."${config.services.authentik.nginx.host}".locations."/".proxyPass;
in {
  options = {
    services.nginx.virtualHosts = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
        options = {
          authentik.enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          authentik.url = lib.mkOption {
            type = lib.types.str;
            default = defaultAuthentikURL;
            defaultText = lib.literalExpression ''config.services.nginx.virtualHosts."''${config.services.authentik.nginx.host}".locations."/".proxyPass'';
          };
        };
        config = lib.mkIf config.authentik.enable {
          locations."/".extraConfig = ''
            auth_request     /outpost.goauthentik.io/auth/nginx;
            error_page       401 = @goauthentik_proxy_signin;
            auth_request_set $auth_cookie $upstream_http_set_cookie;
            add_header       Set-Cookie $auth_cookie;

            # translate headers from the outposts back to the actual upstream
            auth_request_set $authentik_username $upstream_http_x_authentik_username;
            auth_request_set $authentik_groups $upstream_http_x_authentik_groups;
            auth_request_set $authentik_entitlements $upstream_http_x_authentik_entitlements;
            auth_request_set $authentik_email $upstream_http_x_authentik_email;
            auth_request_set $authentik_name $upstream_http_x_authentik_name;
            auth_request_set $authentik_uid $upstream_http_x_authentik_uid;

            proxy_set_header X-authentik-username $authentik_username;
            proxy_set_header X-authentik-groups $authentik_groups;
            proxy_set_header X-authentik-entitlements $authentik_entitlements;
            proxy_set_header X-authentik-email $authentik_email;
            proxy_set_header X-authentik-name $authentik_name;
            proxy_set_header X-authentik-uid $authentik_uid;
          '';
          locations."/outpost.goauthentik.io" = {
            proxyPass = config.authentik.url;
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
          '';
        };
      }));
    };
  };
}
