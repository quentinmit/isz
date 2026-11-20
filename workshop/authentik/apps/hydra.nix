{ config, lib, ... }:
{
  sops.secrets."authentik/apps/hydra/client_id" = {};
  sops.secrets."authentik/apps/hydra/client_secret" = {};
  services.authentik.apps.hydra = {
    name = "Hydra";
    type = "oauth2";
    redirect_uris = "https://hydra.isz.wtf/oidc-callback/isz";
    properties = [
      "goauthentik.io/providers/oauth2/scope-openid"
      "goauthentik.io/providers/oauth2/scope-profile"
      "goauthentik.io/providers/oauth2/scope-entitlements"
      "isz.wtf/email"
      "isz.wtf/nbf/zero"
    ];
    groups = [
      "Residents"
    ];
    entitlements.hydra-admins.groups = [
      "authentik Admins"
    ];
  };
  sops.templates."hydra.conf" = {
    content = ''
      local_auth_enabled = 0
      <oidc>
        <provider isz>
          display_name = "ISZ"
          discovery_url = "https://auth.isz.wtf/application/o/hydra/.well-known/openid-configuration"
          client_id = "${config.sops.placeholder."authentik/apps/hydra/client_id"}"
          client_secret = "${config.sops.placeholder."authentik/apps/hydra/client_secret"}"
          role_claim = "entitlements"
          extra_scopes = "entitlements"
          <role_mapping>
            hydra-admins = admin
            hydra-builders = create-projects
            hydra-builders = eval-jobset
          </role_mapping>
        </provider>
      </oidc>
    '';
    group = "hydra";
    mode = "0440";
  };
  services.hydra.extraConfig = ''
    Include ${config.sops.templates."hydra.conf".path}
  '';
}
