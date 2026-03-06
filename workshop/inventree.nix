{ config, options, lib, pkgs, nixos-inventree, ... }:
{
  imports = [
    nixos-inventree.nixosModules.default
  ];
  config = {
    services.inventree = {
      enable = true;
      packages = options.services.inventree.packages.default.overrideScope (it-final: it-prev: {
          src = it-prev.src.overrideAttrs (old: {
            patches = (old.patches or []) ++ [
              ../nix/pkgs/inventree/sso.patch
            ];
          });
          workspace = it-prev.workspace // {
            deps.default = it-prev.workspace.deps.default // {
              psycopg2 = [ ];
            };
          };
          packageOverrides = lib.composeManyExtensions [
            it-prev.packageOverrides
            (final: prev: {
              psycopg2 = final.hacks.nixpkgsPrebuilt {
                from = final.python.pkgs.psycopg2;
              };
              # nixos-inventree uses weasyprint from nixpkgs, but that now requires a newer tinycss2.
              # Until nixos-inventree has been updated, we inject a nixpkgs tinycss2 to match.
              tinycss2 = final.hacks.nixpkgsPrebuilt {
                from = final.python.pkgs.tinycss2;
              };
            })
          ];
        });
      serverBind = "unix:/run/inventree/inventree.sock";
      config = {
        database = {
          ENGINE = "postgresql";
          NAME = "inventree";
          USER = "inventree";
        };
        site_url = "https://inventree.isz.wtf";
        allowed_hosts = [ "inventree.isz.wtf" ];

        static_root = "/var/lib/inventree/static";
        media_root = "/var/lib/inventree/media";
        backup_dir = "/var/lib/inventree/backup";

        # TODO: trusted_origins = [];
        use_x_forwarded_host = true;
        use_x_forwarded_port = true;
        use_x_forwarded_proto = true;

        global_settings = {
          INVENTREE_COMPANY_NAME = "Ice Station Zebra";
        };
      };
    };
    services.postgresql = {
      ensureDatabases = [ "inventree" ];
      ensureUsers = [
        { name = "inventree"; ensureDBOwnership = true; }
      ];
      authentication = ''
        local inventree inventree peer map=inventree
      '';
      identMap = ''
        inventree root inventree
        inventree inventree inventree
      '';
    };
    systemd.services.inventree-server.serviceConfig = {
      RuntimeDirectory = "inventree";
    };
    users.users."${config.services.nginx.user}".extraGroups = [ "inventree" ];
    services.nginx = {
      upstreams.inventree.servers."unix:/run/inventree/inventree.sock" = {};
      virtualHosts."inventree.isz.wtf" = {
        forceSSL = true;
        enableACME = true;
        locations."/" = {
          proxyPass = "http://inventree";
          proxyWebsockets = true;
        };
        # https://github.com/inventree/InvenTree/blob/master/contrib/container/nginx.conf
        locations."/static/" = {
          alias = "/var/lib/inventree/static/";
        };
        locations."/media/" = {
          alias = "/var/lib/inventree/media/";
          extraConfig = ''
            auth_request /auth;
            add_header Content-disposition "attachment";
          '';
        };
        locations."/auth" = {
          extraConfig = ''
            internal;
            proxy_pass_request_body off;
            proxy_set_header Content-Length "";
            proxy_set_header X-Original-URI $request_uri;
          '';
          proxyPass = "http://inventree/auth/";
        };
      };
    };
  };
}
