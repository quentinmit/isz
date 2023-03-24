{ lib, pkgs, config, options, ... }:
{
  imports = [
    ../nix/telegraf.nix
  ];
  config = let
    fromYAML = yaml:
      builtins.fromJSON (builtins.readFile (pkgs.runCommand "from-yaml" {
        inherit yaml;
        allowSubstitutes = false;
        preferLocalBuild = true;
      } ''
        ${pkgs.remarshal}/bin/remarshal  \
          -if yaml \
          -i <(echo "$yaml") \
          -of json \
          -o $out
      ''));

    readYAML = path: fromYAML (builtins.readFile path);
    pingTargets = [{ host = "overwatch.mit.edu"; }] ++ (readYAML ../telegraf/static/he_lg.yaml).he_lg_ping_targets;
  in {
    sops.secrets.telegraf = {
      owner = config.systemd.services.telegraf.serviceConfig.User;
    };
    services.telegraf.enable = true;
    systemd.services.telegraf.serviceConfig.EnvironmentFile = [
      config.sops.secrets.telegraf.path
    ];
    isz.telegraf = {
      intelRapl = true;
      openweathermap = {
        appId = "$OPENWEATHERMAP_APP_ID";
        cityIds = ["4931972" "4930956" "5087559"];
      };
      mikrotik.api = let defaults = {
        plaintext = true;
        user = "$MIKROTIK_API_USER";
        password = "$MIKROTIK_API_PASSWORD";
      }; in {
        targets = map (t: defaults // t) [
          { ip = "172.30.97.2"; }
          { ip = "172.30.97.3"; }
        ];
      };
      mikrotik.swos = let defaults = {
        user = "$MIKROTIK_SWOS_USER";
        password = "$MIKROTIK_SWOS_PASSWORD";
      }; in {
        targets = map (t: defaults // t) [
          { ip = "172.30.97.16"; }
          { ip = "172.30.97.17"; }
          { ip = "172.30.97.18"; }
        ];
      };
      mikrotik.snmp.targets = [
        # { ip = "172.30.97.1"; }
        { ip = "172.30.97.2"; }
        { ip = "172.30.97.3"; }
        { ip = "172.30.97.16"; }
        { ip = "172.30.97.17"; }
        { ip = "172.30.97.18"; }
      ];
    };
    services.telegraf.extraConfig = {
      inputs.prometheus = lib.attrsets.mapAttrsToList
        (app: url: {
          urls = [url];
          metric_version = 2;
          interval = "60s";
          tags.app = app;
        }) {
          grafana = "https://grafana.isz.wtf/metrics";
          influx = "https://influx.isz.wtf/metrics";
        };
      inputs.ping = [{
        interval = "30s";
        method = "native";
        urls = map (t: t.host) pingTargets;
        ipv6 = false;
      }];
      processors.starlark = [{
        namepass = ["ping"];
        source = ''
          tags = ${builtins.toJSON (builtins.listToAttrs (map (t: { name = t.host; value = t; }) pingTargets))}
          def apply(metric):
            url = metric.tags.get("url")
            extra = tags.get(url)
            if extra:
              extra = dict(extra)
              extra.pop("host")
              if "exchanges" in extra:
                extra["exchanges"] = ", ".join(extra["exchanges"])
              metric.tags.update(extra)
            return metric
        '';
      }];
    };
  };
}
