{ config, lib, pkgs, authentik, nixpkgs-authentik, ... }:
{
  imports = [
    authentik.nixosModules.default
    ./blueprint.nix
    ./apps
  ];
  config = {
    sops.secrets."authentik/environment" = {
      restartUnits = [
        "authentik-migrate.service"
        "authentik-worker.service"
        "authentik.service"
      ];
    };
    services.authentik = {
      enable = true;
      environmentFile = config.sops.secrets."authentik/environment".path;
      nginx = {
        enable = true;
        enableACME = true;
        host = "auth.isz.wtf";
      };
      settings = {
        error_reporting.enabled = false;
        disable_update_check = true;
        disable_startup_analytics = true;
        avatars = "gravatar,initials";
        # Disable outpost discovery since there's no Kubernetes or Docker.
        outposts.discover = false;
      };

      authentikComponents = let
        scope = (authentik.lib.mkAuthentikScope {
          pkgs = authentik.inputs.nixpkgs.legacyPackages.${pkgs.stdenv.system};
        }).overrideScope (final: prev: {
          authentikComponents = prev.authentikComponents // {
            staticWorkdirDeps = prev.authentikComponents.staticWorkdirDeps.override (old: {
              authentik-src = pkgs.applyPatches {
                src = old.authentik-src;
                name = "isz-patched-authentik-source";
                patches = [
                  ./proxy-scopes.patch
                ];
              };
            });
            manage = prev.authentikComponents.manage.override (old: {
              authentikComponents = old.authentikComponents // {
                staticWorkdirDeps = "${./lib}:${old.authentikComponents.staticWorkdirDeps}";
              };
            });
          };
        });
        in scope.authentikComponents;
    };
    isz.telegraf.prometheus.apps.authentik = {
      url = "http://localhost:9300/metrics";
      extraConfig.http_headers.Accept = "text/plain";
    };
  };
}
