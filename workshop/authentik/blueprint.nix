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
        {
          model = "authentik_flows.flow";
          id = "flow";
          identifiers.slug = "default-authentication-flow";
          attrs.designation = "authentication";
          attrs.name = "Ice Station Zebra";
          attrs.title = "Ice Station Zebra";
          attrs.authentication = "none";
        }
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
      ];
    };
  };
}
