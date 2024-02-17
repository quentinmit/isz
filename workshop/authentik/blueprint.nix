{ config, lib, pkgs, ... }:
let
  cfg = config.services.authentik;
  format = pkgs.formats.yaml {};
  blueprintFile = pkgs.runCommandLocal "blueprint.yaml" { } ''
    cp ${format.generate "blueprint.yaml" cfg.blueprint} $out
    sed -i -e "s/'\!\([A-Za-z_]\+\) \(.*\)'/\!\1 \2/;s/^\!\!/\!/;" $out
  '';
  applyBlueprint = name: {
    model = "authentik_blueprints.metaapplyblueprint";
    attrs.identifiers.name = name;
  };
  find = type: field: value: "!Find [${type}, [${field}, ${value}]]";
  findFlow = find "authentik_flows.flow" "slug";
  findSource = find "authentik_core.source" "slug";
  findScope = find "authentik_providers_oauth2.scopemapping" "name";
  findProvider = find "authentik_providers_oauth2.oauth2provider" "slug";
  signing_key = find "authentik_crypto.certificatekeypair" "name" "authentik Self-signed Certificate";
in {
  options = with lib; {
    services.authentik.blueprint = mkOption {
      type = types.nullOr format.type;
      default = null;
    };
  };
  config = {
    users.groups.authentik-blueprint = {};
    sops.templates."blueprint.yaml" = {
      group = "authentik-blueprint";
      mode = "0440";
      file = blueprintFile;
    };

    sops.secrets."authentik/google_oauth/consumer_key" = {};
    sops.secrets."authentik/google_oauth/consumer_secret" = {};

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
        client_id = "$__file{${config.sops.secrets."authentik/apps/grafana/client_id".path}}";
        client_secret = "$__file{${config.sops.secrets."authentik/apps/grafana/client_secret".path}}";
        scopes = "openid email profile";
        auth_url = "${baseUrl}authorize/";
        token_url = "${baseUrl}token/";
        api_url = "${baseUrl}userinfo/";
        role_attribute_path = "contains(groups, 'Grafana Admins') && 'Admin' || contains(groups, 'Grafana Editors') && 'Editor' || 'Viewer'";
      };
    };

    services.authentik.settings.blueprints_dir = "/run/authentik/blueprints-rw";

    systemd.services.authentik-worker.serviceConfig.SupplementaryGroups = ["authentik-blueprint"];
    systemd.services.authentik-worker.preStart = ''
      mkdir -p /run/authentik/blueprints-rw
      cp -aL ${config.services.authentik.authentikComponents.staticWorkdirDeps}/blueprints/* /run/authentik/blueprints-rw/
      cp -aL ${config.sops.templates."blueprint.yaml".path} /run/authentik/blueprints-rw/blueprint.yaml
    '';

    services.authentik.blueprint = {
      version = 1;
      metadata.name = "ISZ";
      entries = [
        (applyBlueprint "Default - Authentication flow")
        (applyBlueprint "Default - Source authentication flow")
        (applyBlueprint "Default - Source enrollment flow")
        (applyBlueprint "Default - Provider authorization flow (implicit consent)")
        {
          model = "authentik_flows.flow";
          id = "default-identification-flow";
          identifiers.slug = "default-authentication-flow";
          attrs.designation = "authentication";
          attrs.name = "Ice Station Zebra";
          attrs.title = "Ice Station Zebra";
          attrs.authentication = "none";
        }
        # OAuth2 sources
        {
          model = "authentik_sources_oauth.oauthsource";
          name = "Google";
          identifiers.slug = "google";
          attrs = {
            access_token_url = "https://oauth2.googleapis.com/token";
            authentication_flow = findFlow "default-source-authentication";
            authorization_url = "https://accounts.google.com/o/oauth2/v2/auth";
            consumer_key = config.sops.placeholder."authentik/google_oauth/consumer_key";
            consumer_secret = config.sops.placeholder."authentik/google_oauth/consumer_secret";
            enabled = true;
            enrollment_flow = findFlow "default-source-enrollment";
            name = "Google";
            oidc_jwks_url = "https://www.googleapis.com/oauth2/v3/certs";
            policy_engine_mode = "any";
            profile_url = "https://openidconnect.googleapis.com/v1/userinfo";
            provider_type = "google";
            slug = "google";
            user_matching_mode = "identifier";
            user_path_template = "goauthentik.io/sources/%(slug)s";
          };
        }
        rec {
          model = "authentik_stages_identification.identificationstage";
          id = "default-authentication-identification";
          identifiers.name = id;
          attrs.user_fields = [
            "email"
            "username"
          ];
          attrs.sources = [
            (findSource "authentik-built-in")
            (findSource "google")
          ];
        }
        # Applications
        {
          model = "authentik_providers_oauth2.oauth2provider";
          identifiers.name = "Grafana";
          attrs = {
            name = "Grafana";
            redirect_uris = "https://grafana.isz.wtf/login/generic_oauth";

            authentication_flow = findFlow "default-authentication-flow";
            authorization_flow = findFlow "default-provider-authorization-implicit-consent";

            client_id = config.sops.placeholder."authentik/apps/grafana/client_id";
            client_secret = config.sops.placeholder."authentik/apps/grafana/client_secret";
            client_type = "confidential";

            include_claims_in_id_token = true;
            issuer_mode = "per_provider";
            property_mappings = [
              (findScope "authentik default OAuth Mapping: OpenID 'email'")
              (findScope "authentik default OAuth Mapping: OpenID 'openid'")
              (findScope "authentik default OAuth Mapping: OpenID 'profile'")
            ];
            inherit signing_key;
            sub_mode = "hashed_user_id";

            access_code_validity = "minutes=1";
            access_token_validity = "minutes=5";
            refresh_token_validity = "days=30";
          };
        }
        {
          model = "authentik_core.application";
          identifiers.slug = "grafana";
          attrs = {
            name = "Grafana";
            slug = "grafana";
            policy_engine_mode = "any";
            provider = findProvider "grafana";
          };
        }
      ];
    };
  };
}
