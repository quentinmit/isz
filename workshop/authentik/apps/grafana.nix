{ config, lib, pkgs, ... }:
{
  sops.secrets."authentik/apps/grafana/client_id" = {
    owner = config.systemd.services.grafana.serviceConfig.User;
  };
  sops.secrets."authentik/apps/grafana/client_secret" = {
    owner = config.systemd.services.grafana.serviceConfig.User;
  };
  services.grafana.settings = let
    baseUrl = "https://auth.isz.wtf/application/o/";
  in {
    auth.oauth_auto_login = true;
    auth.signout_redirect_url = "${baseUrl}grafana/end-session/";
    "auth.generic_oauth" = {
      name = "authentik";
      enabled = true;
      use_refresh_token = true;
      client_id = "$__file{${config.sops.secrets."authentik/apps/grafana/client_id".path}}";
      client_secret = "$__file{${config.sops.secrets."authentik/apps/grafana/client_secret".path}}";
      scopes = "openid email profile offline_access goauthentik.io/application/loki";
      auth_url = "${baseUrl}authorize/";
      token_url = "${baseUrl}token/";
      api_url = "${baseUrl}userinfo/";
      login_attribute_path = "preferred_username";
      role_attribute_path = "contains(groups, 'Grafana Admins') && 'Admin' || contains(groups, 'Grafana Editors') && 'Editor' || 'Viewer'";
      allow_assign_grafana_admin = true;
    };
  };
  services.authentik.apps.grafana = {
    name = "Grafana";
    type = "oauth2";
    redirect_uris = "https://grafana.isz.wtf/login/generic_oauth";
    properties = [
      "goauthentik.io/providers/oauth2/scope-email"
      "goauthentik.io/providers/oauth2/scope-openid"
      "goauthentik.io/providers/oauth2/scope-profile"
      "goauthentik.io/providers/oauth2/scope-offline_access"
      "goauthentik.io/application/loki"
    ];
  };
}
