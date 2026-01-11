{ config, lib, ... }:
{
  sops.secrets."authentik/apps/homebox/client_id" = {};
  sops.secrets."authentik/apps/homebox/client_secret" = {};
  services.authentik.apps.homebox = {
    name = "Homebox";
    type = "oauth2";
    redirect_uris = "https://homebox.isz.wtf/api/v1/users/login/oidc/callback";
    properties = [
      "goauthentik.io/providers/oauth2/scope-email"
      "goauthentik.io/providers/oauth2/scope-openid"
      "goauthentik.io/providers/oauth2/scope-profile"
      "goauthentik.io/providers/oauth2/scope-entitlements"
    ];
    groups = [
      "Residents"
    ];
    entitlements.Admin.groups = [
      "authentik Admins"
    ];
  };
  services.homebox.settings = {
    HBOX_OPTIONS_ALLOW_LOCAL_LOGIN = "false";
    HBOX_OIDC_ENABLED = "true";
    HBOX_OIDC_GROUP_CLAIM = "entitlements";
    HBOX_OIDC_ISSUER_URL = "https://auth.isz.wtf/application/o/homebox/";
    HBOX_OIDC_AUTO_REDIRECT = "true";
  };
  sops.templates."homebox.env".content = ''
    HBOX_OIDC_CLIENT_ID="${config.sops.placeholder."authentik/apps/homebox/client_id"}"
    HBOX_OIDC_CLIENT_SECRET="${config.sops.placeholder."authentik/apps/homebox/client_secret"}"
  '';
  systemd.services.homebox.serviceConfig.EnvironmentFile = config.sops.templates."homebox.env".path;
}
