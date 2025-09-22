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
  inherit (config.lib.authentik) keyOf find findApp findProvider findGroup findFlow findScope findSAMLPropertyMapping;
  signing_key = find "authentik_crypto.certificatekeypair" "name" "authentik Self-signed Certificate";
in {
  options = with lib; {
    services.authentik = {
      blueprint = mkOption {
        type = types.nullOr format.type;
        default = null;
      };
      samlPropertyMappings = mkOption {
        type = with types; attrsOf format.type;
        default = {};
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
              type = enum ["oauth2" "proxy" "saml"];
            };
            redirect_uris = mkOption {
              type = coercedTo
                str (s: lib.splitString "\n" (lib.trim s))
                (listOf
                  (coercedTo
                    str (url: { matching_mode = "strict"; inherit url; })
                    (submodule {
                      options.matching_mode = mkOption {
                        type = enum ["strict" "regex"];
                        default = "strict";
                      };
                      options.url = mkOption {
                        type = str;
                      };
                    })));
            };
            host = mkOption {
              type = str;
            };
            nginx = mkEnableOption "Configure nginx for this host";
            properties = mkOption {
              type = listOf str;
            };
            groups = mkOption {
              type = listOf str;
              default = [];
            };
            entitlements = mkOption {
              type = let
                inherit (config) slug;
              in attrsOf (submodule ({ name, config, ... }: {
                options = let
                  id = "${slug}-${name}";
                in {
                  groups = mkOption {
                    type = listOf str;
                    default = [];
                  };
                  entitlement = mkOption {
                    inherit (format) type;
                    default = {
                      model = "authentik_core.applicationentitlement";
                      identifiers.name = name;
                      identifiers.app = findApp slug;
                      inherit id;
                    };
                  };
                  blueprint = mkOption {
                    inherit (format) type;
                    default = [config.entitlement] ++ (lib.imap0 (i: name: {
                      model = "authentik_policies.policybinding";
                      identifiers.target = keyOf id;
                      identifiers.order = i;
                      attrs.group = findGroup name;
                    }) config.groups);
                  };
                };
              }));
              default = {};
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
              default = lib.optional (config.provider != null) config.provider ++ [config.app] ++ (lib.imap0 (i: name: {
                model = "authentik_policies.policybinding";
                identifiers.target = findApp config.slug;
                identifiers.order = i;
                attrs.group = findGroup name;
              }) config.groups) ++ (lib.concatLists (lib.mapAttrsToList (_: e: e.blueprint) config.entitlements));
            };
          };
          config = {
            properties = let
              mkDefaultIf = c: v: lib.mkIf c (lib.mkDefault v);
            in lib.mkMerge [
              (mkDefaultIf (config.type == "oauth2") [
                "goauthentik.io/providers/oauth2/scope-email"
                "goauthentik.io/providers/oauth2/scope-openid"
                "goauthentik.io/providers/oauth2/scope-profile"
              ])
              (mkDefaultIf (config.type == "proxy") [
                "goauthentik.io/providers/oauth2/scope-email"
                "goauthentik.io/providers/oauth2/scope-openid"
                "goauthentik.io/providers/oauth2/scope-profile"
                "goauthentik.io/providers/proxy/scope-proxy"
              ])
              (mkDefaultIf (config.type == "saml") [])
            ];
            redirect_uris = lib.mkIf (config.type == "proxy") [
              ''https://${config.host}/outpost.goauthentik.io/callback\?X-authentik-auth-callback=true''
              ''https://${config.host}\?X-authentik-auth-callback=true''
            ];
            provider = let
              common = {
                identifiers.name = config.name;
                attrs = {
                  authentication_flow = findFlow "default-authentication-flow";
                  authorization_flow = findFlow "default-provider-authorization-implicit-consent";
                  invalidation_flow = findFlow "default-provider-invalidation-flow";
                };
              };
              oauth2 = {
                model = "authentik_providers_oauth2.oauth2provider";
                inherit (common) identifiers;
                attrs = common.attrs // {
                  inherit (config) redirect_uris;

                  client_id = lib.mkIf (sopsPlaceholder ? "authentik/apps/${config.slug}/client_id") sopsPlaceholder."authentik/apps/${config.slug}/client_id";
                  client_secret = lib.mkIf (sopsPlaceholder ? "authentik/apps/${config.slug}/client_secret") sopsPlaceholder."authentik/apps/${config.slug}/client_secret";
                  client_type = "confidential";

                  include_claims_in_id_token = true;
                  issuer_mode = "per_provider";
                  property_mappings = map findScope config.properties;
                  inherit signing_key;
                  sub_mode = "hashed_user_id";

                  access_code_validity = "minutes=1";
                  access_token_validity = "minutes=5";
                  refresh_token_validity = "days=30";
                };
              };
              proxy = {
                model = "authentik_providers_proxy.proxyprovider";
                inherit (common) identifiers;
                attrs = oauth2.attrs // {
                  intercept_header_auth = true;
                  mode = "forward_single";

                  access_token_validity = "hours=24";

                  external_host = "https://${config.host}";
                };
              };
              saml = {
                model = "authentik_providers_saml.samlprovider";
                inherit (common) identifiers;
                attrs = common.attrs // {
                  property_mappings = map findSAMLPropertyMapping config.properties;
                  signing_kp = signing_key;
                  sign_assertion = true;
                };
              };
            in lib.mkMerge [
              (lib.mkIf (config.type == "oauth2") oauth2)
              (lib.mkIf (config.type == "proxy") proxy)
              (lib.mkIf (config.type == "saml") saml)
            ];
          };
        }));
      };
    };
  };
  config = lib.mkMerge [
    (lib.mkIf (cfg.blueprint != null) {
      users.groups.authentik-blueprint = {};
      sops.templates."blueprint.yaml" = {
        group = "authentik-blueprint";
        mode = "0440";
        file = blueprintFile;
      };

      services.authentik.settings.blueprints_dir = "/run/authentik/blueprints-rw";

      systemd.services.authentik-worker.serviceConfig.SupplementaryGroups = ["authentik-blueprint"];
      systemd.services.authentik-worker.preStart = ''
        mkdir -p /run/authentik/blueprints-rw
        cp -aL ${config.services.authentik.authentikComponents.staticWorkdirDeps}/blueprints/* /run/authentik/blueprints-rw/
        cp -aL ${config.sops.templates."blueprint.yaml".path} /run/authentik/blueprints-rw/blueprint.yaml
      '';
      systemd.services.authentik-worker.restartTriggers = [blueprintFile];
    })
    {
      services.nginx.virtualHosts = builtins.listToAttrs (
        builtins.map
          (app: lib.nameValuePair
            app.host
            {
              authentik.enable = true;
            }
          )
          (builtins.filter
            (app: app.type == "proxy" && app.nginx)
            (lib.attrValues cfg.apps)
          )
      );
    }
  ];
}
