{ config, lib, pkgs, ... }:
{
  sops.secrets."authentik/apps/jellyfin/client_id" = {};
  sops.secrets."authentik/apps/jellyfin/client_secret" = {};
  services.authentik.apps.jellyfin = {
    name = "Jellyfin";
    type = "oauth2";
    redirect_uris = "https://jellyfin.isz.wtf/sso/OID/redirect/ISZ";
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
}
