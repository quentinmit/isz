{ config, lib, pkgs, ... }:
# To provision a Loki token, first edit the Loki provider to have `days=50000`, then impersonate the service account and go to Loki.
# Then,
# systemd-run --pty --collect   --property DynamicUser=true --property EnvironmentFile=/run/secrets/authentik/environment --property StateDirectory=authentik --property User=authentik   --working-directory /var/lib/authentik --property SupplementaryGroups=redis-authentik -- /nix/store/4mhvdij442y364h0mxvyi6midszyswid-authentik-manage/bin/manage.py shell
# from authentik.providers.oauth2.models import AccessToken
# t = AccessToken.objects.get(provider=Provider.objects.get(name="Loki"), user=User.objects.get(name="vector@foo.isz.wtf"))
# t.expiring = False
# t.session = None
# t.save()

let
  cfg = config.isz.vector;
in {
  options = with lib; {
    isz.vector = {
      enable = mkEnableOption "Vector agent";
      journald.services = mkOption {
        type = types.attrsOf (types.submodule ({ config, name, ... }: {
          options = {
            transforms = mkOption {
              type = with types; listOf anything;
            };
            outputName = mkOption {
              type = types.str;
              readOnly = true;
            };
            settings = mkOption {
              type = types.anything;
            };
          };
          config = {
            settings.transforms = lib.listToAttrs (lib.lists.imap1 (i: t: lib.nameValuePair
              "journald_${name}_${toString i}"
              (t // {
                inputs = [
                  (if i > 1 then "journald_${name}_${toString (i - 1)}" else "journald_route.${name}")
                ];
              })
            ) config.transforms);
            outputName = "journald_${name}_${toString (lib.length config.transforms)}";
          };
        }));
        default = {};
      };
    };
  };
  config = lib.mkIf cfg.enable {
    sops.secrets."vector/loki/oauth_token" = {};
    systemd.services.vector.serviceConfig.LoadCredential = "loki_oauth_token:${config.sops.secrets."vector/loki/oauth_token".path}";
    services.vector = {
      enable = true;
      package = pkgs.unstable.vector;
      journaldAccess = true;
      settings = lib.mkMerge ([
        {
          api.enabled = true;
          secret.systemd.type = "exec";
          secret.systemd.command = [
            (pkgs.writers.writePython3 "vector-secrets" {} ''
              import os
              import os.path
              import json
              import sys

              req = json.load(sys.stdin)
              assert req.get("version") == "1.0"

              out = {}
              for name in req["secrets"]:
                  try:
                      data = open(
                          os.path.join(
                              os.environ["CREDENTIALS_DIRECTORY"],
                              name,
                          )
                      ).read()
                      out[name] = {"value": data, "error": None}
                  except OSError as e:
                      out[name] = {"value": None, "error": str(e)}
              print(json.dumps(out))
            '')
          ];
          sources.journald = {
            type = "journald";
            current_boot_only = false;
          };
          transforms.journald_remap = {
            type = "remap";
            inputs = ["journald"];
            # Valid levels at: https://github.com/grafana/loki/blob/main/pkg/util/constants/levels.go#L15
            # critical
            # fatal
            # error
            # warn
            # info
            # debug
            # trace
            # unknown
            source = ''
              LEVELS = {
                "0": "fatal", # emerg
                "1": "error", # alert
                "2": "error", # crit
                "3": "error", # err
                "4": "warn", # warning
                "5": "info", # notice
                "6": "info", # info
                "7": "debug", # debug
              }
              .labels = {}
              priority, err = to_syslog_level(to_int(.PRIORITY) ?? -1)
              if err == null {
                .priority = priority
              }
              if exists(.PRIORITY) {
                level = get!(LEVELS, [.PRIORITY])
                if level != null {
                  .level = level
                }
              }
              facility, err = to_syslog_facility(to_int(.SYSLOG_FACILITY) ?? -1)
              if err == null {
                .facility = facility
              }
              ${lib.concatMapStringsSep "\n" (key: ''
                if exists(.${key}) {
                  .labels.${key} = .${key}
                  del(.${key})
                }
              '') [
                "host"
                "source_type"
              ]}
              ${pkgs.unstable.lib.concatMapAttrsStringSep "\n" (out: src: ''
                if exists(.${src}) {
                  .labels.${out} = .${src}
                }
              '') {
                service_namespace = "_SYSTEMD_SLICE";
                service_name = "_SYSTEMD_UNIT";
              }}
              del(.source_type)
              del(.host)
              structured_metadata = filter(.) -> |key, _value| {
                !includes(["labels", "message", "timestamp"], key)
              }
              # Work around https://github.com/grafana/loki/issues/16148
              structured_metadata = map_keys(structured_metadata) -> |key| {
                if starts_with(key, "_") {
                  "trusted" + key
                } else {
                  key
                }
              }
              . = {
                "labels": .labels,
                "message": .message,
                "timestamp": .timestamp,
                "structured_metadata": structured_metadata,
              }
              TELEGRAF_LEVELS = {
                "E": "error",
                "W": "warn",
                "I": "info",
                "D": "debug",
              }
              if structured_metadata.trusted_COMM == "telegraf" {
                parts, err = parse_regex(.message, r'(?P<time>\S+)\s+(?P<level>.)!\s+(?P<message>(\[(?P<plugin>[^]]+)\]\s+)?.+)')
                if err == null {
                  .structured_metadata.level = get!(TELEGRAF_LEVELS, [parts.level])
                  if parts.plugin != null {
                    .structured_metadata.plugin = parts.plugin
                  }
                  .message = parts.message
                }
              }
            '';
          };
          transforms.journald_route = {
            inputs = ["journald_remap"];
            type = "exclusive_route";
            routes = lib.map (name: {
              inherit name;
              condition = ''.structured_metadata.trusted_SYSTEMD_UNIT == "${name}.service"'';
            }) (lib.attrNames config.isz.vector.journald.services);
          };
          sinks.loki_journald = {
            type = "loki";
            inputs = [
              "journald_route._unmatched"
            ] ++ lib.mapAttrsToList (_: config: config.outputName) cfg.journald.services;
            endpoint = "https://loki.isz.wtf";
            encoding.codec = "raw_message";
            remove_label_fields = true;
            labels."*" = "{{ labels }}";
            remove_structured_metadata_fields = true;
            structured_metadata."*" = "{{ structured_metadata }}";
            slugify_dynamic_fields = false;
            auth.strategy = "bearer";
            auth.token = "SECRET[systemd.loki_oauth_token]";
          };
        }
      ] ++ (lib.mapAttrsToList (_: config: config.settings) cfg.journald.services));
    };
  };
}
