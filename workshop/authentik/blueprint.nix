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
  keyOf = id: "!KeyOf ${id}";
  find = type: field: value: "!Find [${type}, [${field}, ${value}]]";
  findFlow = find "authentik_flows.flow" "slug";
  findSource = find "authentik_core.source" "slug";
  # TODO: Figure out how to match scope mappings by the `managed` key instead.
  findScope = find "authentik_providers_oauth2.scopemapping" "scope_name";
  findProvider = find "authentik_providers_oauth2.oauth2provider" "name";
  findPrompt = find "authentik_stages_prompt.prompt" "name";
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
            host = mkOption {
              type = str;
            };
            nginx = mkEnableOption "Configure nginx for this host";
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
              inherit (format) type;
              default = {
                model = "authentik_core.application";
                identifiers.slug = config.slug;
                attrs = {
                  inherit (config) name;
                  inherit (config) slug;
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
                  authentication_flow = findFlow "default-authentication-flow";
                  authorization_flow = findFlow "default-provider-authorization-implicit-consent";

                  refresh_token_validity = "days=30";
                };
              }
              (lib.mkIf (config.type == "oauth2") {
                model = "authentik_providers_oauth2.oauth2provider";
                attrs = {
                  inherit (config) redirect_uris;

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

                  external_host = "https://${config.host}";
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
        # Login flows
        {
          model = "authentik_flows.flow";
          identifiers.slug = "default-authentication-flow";
          attrs.designation = "authentication";
          attrs.name = "Ice Station Zebra";
          attrs.title = "Ice Station Zebra";
          attrs.authentication = "none";
        }
        {
          model = "authentik_stages_user_login.userloginstage";
          identifiers.name = "default-authentication-login";
          attrs.remember_me_offset = "days=30";
          attrs.session_duration = "seconds=0";
        }
        {
          model = "authentik_stages_user_login.userloginstage";
          identifiers.name = "default-source-authentication-login";
          attrs.remember_me_offset = "days=7";
          attrs.session_duration = "seconds=0";
        }
        # Enrollment flows
        {
          model = "authentik_flows.flow";
          identifiers.slug = "enrollment-invitation";
          id = "enrollment-invitation-flow";
          attrs.name = "enrollment-invitation";
          attrs.title = "Invitation";
          attrs.designation = "enrollment";
          attrs.authentication = "require_unauthenticated";
        }
        {
          model = "authentik_stages_invitation.invitationstage";
          identifiers.name = "enrollment-invitation";
          id = "enrollment-invitation-stage-1";
          attrs.continue_flow_without_invitation = false;
        }
        {
          model = "authentik_stages_prompt.prompt";
          identifiers.name = "enrollment-invitation-field-username";
          attrs.field_key = "username";
          attrs.label = "Username";
          attrs.required = true;
          attrs.type = "text";
          attrs.placeholder = "Username";
          attrs.order = 100;
        }
        {
          model = "authentik_stages_prompt.prompt";
          identifiers.name = "enrollment-invitation-field-password";
          attrs.field_key = "password";
          attrs.label = "Password";
          attrs.required = true;
          attrs.type = "password";
          attrs.placeholder = "Password";
          attrs.order = 150;
        }
        {
          model = "authentik_stages_prompt.prompt";
          identifiers.name = "enrollment-invitation-field-password-repeat";
          attrs.field_key = "password-repeat";
          attrs.label = "Password (repeat)";
          attrs.required = true;
          attrs.type = "password";
          attrs.placeholder = "Password (repeat)";
          attrs.order = 160;
        }
        {
          model = "authentik_stages_prompt.prompt";
          identifiers.name = "enrollment-invitation-field-name";
          attrs.field_key = "name";
          attrs.label = "Name";
          attrs.required = true;
          attrs.type = "text";
          attrs.placeholder = "Name";
          attrs.order = 200;
        }
        {
          model = "authentik_stages_prompt.prompt";
          identifiers.name = "enrollment-invitation-field-email";
          attrs.field_key = "email";
          attrs.label = "Email";
          attrs.required = true;
          attrs.type = "text";
          attrs.placeholder = "Email";
          attrs.order = 250;
        }
        {
          model = "authentik_stages_prompt.promptstage";
          identifiers.name = "enrollment-invitation-prompt";
          id = "enrollment-invitation-stage-2";
          attrs.fields = map findPrompt [
            "enrollment-invitation-field-username"
            "enrollment-invitation-field-password"
            "enrollment-invitation-field-password-repeat"
            "enrollment-invitation-field-name"
            "enrollment-invitation-field-email"
          ];
        }
        {
          model = "authentik_stages_user_write.userwritestage";
          identifiers.name = "enrollment-invitation-write";
          id = "enrollment-invitation-stage-3";
          attrs.user_creation_mode = "always_create";
        }
        {
          model = "authentik_flows.flowstagebinding";
          identifiers = {
            target = keyOf "enrollment-invitation-flow";
            stage = keyOf "enrollment-invitation-stage-1";
            order = 10;
          };
        }
        {
          model = "authentik_flows.flowstagebinding";
          identifiers = {
            target = keyOf "enrollment-invitation-flow";
            stage = keyOf "enrollment-invitation-stage-2";
            order = 20;
          };
        }
        {
          model = "authentik_flows.flowstagebinding";
          identifiers = {
            target = keyOf "enrollment-invitation-flow";
            stage = keyOf "enrollment-invitation-stage-3";
            order = 30;
          };
        }
        # Require invitation for source enrollment
        {
          model = "authentik_policies_expression.expressionpolicy";
          identifiers.name = "source-enrollment-if-invitation";
          id = "source-enrollment-if-invitation-policy";
          attrs.expression = ''
            from authentik.stages.invitation.models import Invitation
            google_username = context.get("oauth_userinfo", {}).get("email")
            if not google_username:
              return False
            try:
              Invitation.objects.get(fixed_data__email=google_username)
            except:
              return False
            return True
          '';
        }
        # Require an invitation for source enrollment
        {
          model = "authentik_flows.flow";
          identifiers.slug = "default-source-enrollment";
          id = "default-source-enrollment-flow";
          attrs.policy_engine_mode = "all";
        }
        {
          model = "authentik_policies.policybinding";
          identifiers.order = 1;
          attrs.policy = keyOf "source-enrollment-if-invitation-policy";
          attrs.target = keyOf "default-source-enrollment-flow";
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
            user_matching_mode = "identifier";
            user_path_template = "goauthentik.io/sources/%(slug)s";
          };
        }
        {
          model = "authentik_stages_identification.identificationstage";
          identifiers.name = "default-authentication-identification";
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
    services.nginx.virtualHosts = builtins.listToAttrs (
      builtins.map
        (app: lib.nameValuePair
          app.host
          {
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
          }
        )
        (builtins.filter
          (app: app.type == "proxy" && app.nginx)
          (lib.attrValues cfg.apps)
        )
    );
  };
}
