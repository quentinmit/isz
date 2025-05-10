{ config, pkgs, lib, self, specialArgs, ... }:
let
  bitmagnetUid = 900;
in {
  systemd.services."container@rtorrent" = let
    inherit (config.systemd.services.bitmagnet) requires;
  in {
    inherit requires;
    after = requires;
  };

  services.bitmagnet = {
    enable = true;
  };
  sops.secrets."bitmagnet/tmdb_api_key" = {};
  sops.templates."bitmagnet.env".content = ''
    TMDB_API_KEY=${config.sops.placeholder."bitmagnet/tmdb_api_key"}
  '';
  systemd.services.bitmagnet.serviceConfig = {
    ExecStart = lib.mkForce "${config.services.bitmagnet.package}/bin/bitmagnet worker run --keys http_server --keys queue_server";
    EnvironmentFile = config.sops.templates."bitmagnet.env".path;
  };
  users.users.bitmagnet.uid = bitmagnetUid;
  users.groups.bitmagnet.gid = bitmagnetUid;

  containers.rtorrent = {
    bindMounts."/var/run/postgresql" = {
      hostPath = "/var/run/postgresql/";
      isReadOnly = false;
    };
    inherit specialArgs;
    config = { config, pkgs, lib, ... }: {
      users.users.bitmagnet.uid = bitmagnetUid;
      users.groups.bitmagnet.gid = bitmagnetUid;

      services.bitmagnet = {
        enable = true;
        useLocalPostgresDB = false;
      };
      systemd.services.bitmagnet.serviceConfig.ExecStart = lib.mkForce "${config.services.bitmagnet.package}/bin/bitmagnet worker run --keys dht_crawler";
    };
  };
}
