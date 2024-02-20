{ config, lib, pkgs, ... }:
let
  cfg = config.services.authentik;
  sopsPlaceholder = config.sops.placeholder;
  format = pkgs.formats.yaml {};
  blueprintFile = (format.generate "blueprint.yaml" cfg.blueprint).overrideAttrs {
    buildCommand = ''
      json2yaml --yaml-width inf "$valuePath" | sed -e "
        s/'\!\([A-Za-z_]\+\) \(.*\)'/\!\1 \2/
        s/^\!\!/\!/
        T
        s/'''/'/g
      " > "$out"
    '';
  };
  applyBlueprint = name: {
    model = "authentik_blueprints.metaapplyblueprint";
    attrs.identifiers.name = name;
  };
  find = type: field: value: "!Find [${type}, [${field}, ${value}]]";
  findFlow = find "authentik_flows.flow" "slug";
  findSource = find "authentik_core.source" "slug";
  # TODO: Figure out how to match scope mappings by the `managed` key instead.
  findScope = find "authentik_providers_oauth2.scopemapping" "scope_name";
  findProvider = find "authentik_providers_oauth2.oauth2provider" "name";
  signing_key = find "authentik_crypto.certificatekeypair" "name" "authentik Self-signed Certificate";
in {
  options = with lib; {
    services.authentik = {
      blueprint = mkOption {
        type = types.nullOr format.type;
        default = null;
      };
      apps = mkOption {
        default = {};
        type = with types; attrsOf (submodule ({ name, config, ... }: {
          options = {
            name = mkOption {
              type = str;
              default = name;
            };
            slug = mkOption {
              type = str;
              default = name;
            };
            type = mkOption {
              type = enum ["oauth2" "proxy"];
            };
            redirect_uris = mkOption {
              type = lines;
            };
            properties = mkOption {
              type = listOf str;
              default = [
                "email"
                "openid"
                "profile"
              ];
            };
            provider = mkOption {
              type = nullOr format.type;
              default = null;
            };
            app = mkOption {
              type = format.type;
              default = {
                model = "authentik_core.application";
                identifiers.slug = config.slug;
                attrs = {
                  name = config.name;
                  slug = config.slug;
                  policy_engine_mode = "any";
                  provider = findProvider config.name;
                };
              };
            };
            blueprint = mkOption {
              type = listOf attrs;
              readOnly = true;
              visible = false;
              default = lib.optional (config.provider != null) config.provider ++ [config.app];
            };
          };
          config = {
            provider = lib.mkMerge [
              {
                identifiers.name = config.name;
                attrs = {
                  name = config.name;

                  authentication_flow = findFlow "default-authentication-flow";
                  authorization_flow = findFlow "default-provider-authorization-implicit-consent";

                  refresh_token_validity = "days=30";
                };
              }
              (lib.mkIf (config.type == "oauth2") {
                model = "authentik_providers_oauth2.oauth2provider";
                attrs = {
                  redirect_uris = config.redirect_uris;

                  client_id = sopsPlaceholder."authentik/apps/${config.slug}/client_id";
                  client_secret = sopsPlaceholder."authentik/apps/${config.slug}/client_secret";
                  client_type = "confidential";

                  include_claims_in_id_token = true;
                  issuer_mode = "per_provider";
                  property_mappings = map findScope config.properties;
                  inherit signing_key;
                  sub_mode = "hashed_user_id";

                  access_code_validity = "minutes=1";
                  access_token_validity = "minutes=5";
                };
              })
              (lib.mkIf (config.type == "proxy") {
                model = "authentik_providers_proxy.proxyprovider";
                attrs = {
                  intercept_header_auth = true;
                  mode = "forward_single";

                  access_token_validity = "hours=24";
                };
              })
            ];
          };
        }));
      };
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
    systemd.services.authentik-worker.restartTriggers = [blueprintFile];

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
      ] ++ lib.concatMap (app: app.blueprint) (lib.attrValues cfg.apps) ++ [
        {
          model = "authentik_outposts.outpost";
          identifiers.managed = "goauthentik.io/outposts/embedded";
          attrs.providers = builtins.map (p: findProvider p.name) (builtins.filter (p: p.type == "proxy") (lib.attrValues cfg.apps));
        }
      ];
    };
  };
}
