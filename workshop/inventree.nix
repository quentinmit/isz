{ config, lib, pkgs, nixos-inventree, ... }:
{
  imports = [
    nixos-inventree.nixosModules.default
  ];
  config = {
    nixpkgs.overlays = [(final: prev: {
      inventree = prev.inventree.overrideScope (it-final: it-prev: {
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
        packageOverrides = final.lib.composeManyExtensions [
          it-prev.packageOverrides
          (final: prev: {
            psycopg2 = final.hacks.nixpkgsPrebuilt {
              from = final.python.pkgs.psycopg2;
            };
          })
        ];
      });
    })];
    services.inventree = {
      enable = true;
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
