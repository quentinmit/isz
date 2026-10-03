{ config, lib, pkgs, ... }:
let
  users = {
    quentin = {};
    "telegraf@workshop.isz.wtf" = {};
    "grafana@workshop.isz.wtf" = {};
    "pnio2mqtt@workshop.isz.wtf" = {};
    "telegraf@bedroom-pi.isz.wtf".sopsFile = ../bedroom-pi/shared-secrets.yaml;
    "pnio2mqtt@bedroom-pi.isz.wtf".sopsFile = ../bedroom-pi/shared-secrets.yaml;
    "telegraf@atlas.comclub.org".sopsFile = ../atlas.comclub.org/shared-secrets.yaml;
    "telegraf@build-arm.isz.wtf".sopsFile = ../build-arm/shared-secrets.yaml;
    "telegraf@goddard.isz.wtf".sopsFile = ../goddard/shared-secrets.yaml;
    "telegraf@uconsole.isz.wtf".sopsFile = ../uconsole/shared-secrets.yaml;
    "telegraf@heartofgold.isz.wtf".sopsFile = ../heartofgold/shared-secrets.yaml;
    "telegraf@mnemosyne.isz.wtf".sopsFile = ../mnemosyne/shared-secrets.yaml;
  };
in {
  sops.secrets = lib.mapAttrs' (name: v: lib.nameValuePair "greptimedb/users/${name}" v) users;
  sops.templates."greptimedb-users" = {
    owner = "greptimedb";
    path = "/var/lib/greptimedb/users";
    content = lib.concatMapAttrsStringSep "\n" (name: _: "${name}=${config.sops.placeholder."greptimedb/users/${name}"}") users;
  };
  environment.systemPackages = with pkgs; [
    greptimedb
    pqrs
  ];
  services.greptimedb = {
    enable = true;
    config.user_provider = "watch_file_user_provider:${config.sops.templates."greptimedb-users".path}";
  };
  services.nginx = {
    upstreams.greptimedb.servers."127.0.0.1:4000" = {};
    virtualHosts."greptimedb.isz.wtf" = {
      forceSSL = true;
      enableACME = true;
      locations."/" = {
        proxyPass = "http://greptimedb";
        proxyWebsockets = true;
        # TODO: Configure authentication and allow external access
        extraConfig = ''
          proxy_buffering off;
          allow 172.30.96.0/23;
          deny all;
          client_max_body_size 100M;
        '';
      };
    };
  };
}
