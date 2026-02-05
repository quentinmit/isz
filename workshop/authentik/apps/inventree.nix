{ config, lib, ... }:
{
  sops.secrets."authentik/apps/inventree/client_id" = {};
  sops.secrets."authentik/apps/inventree/client_secret" = {};
  services.authentik.apps.inventree = {
    name = "Inventree";
    type = "oauth2";
    redirect_uris = "https://inventree.isz.wtf/accounts/isz/login/callback/";
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
  services.inventree = {
    config = {
      social_backends = [
        "allauth.socialaccount.providers.openid_connect"
      ];
      global_settings = {
        LOGIN_ENABLE_SSO = true;
        LOGIN_ENABLE_SSO_REG = true;
        LOGIN_ENABLE_PWD_FORGOT = false;
      };
    };
  };
  sops.templates."inventree.env".content = ''
    INVENTREE_SOCIAL_PROVIDERS=${lib.strings.toJSON (lib.strings.toJSON {
      openid_connect.APPS = [{
        provider_id = "isz";
        name = "ISZ";
        client_id = config.sops.placeholder."authentik/apps/inventree/client_id";
        secret = config.sops.placeholder."authentik/apps/inventree/client_secret";
        settings.server_url = "https://auth.isz.wtf/application/o/inventree/.well-known/openid-configuration";
        settings.token_auth_method = "client_secret_basic";
      }];
    })}
  '';
  systemd.services.inventree-server.serviceConfig.EnvironmentFile = config.sops.templates."inventree.env".path;
}
