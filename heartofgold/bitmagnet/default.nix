{ config, pkgs, lib, self, specialArgs, ... }:
let
  bitmagnetUid = 900;
in {
  systemd.services."container@rtorrent" = let
    inherit (config.systemd.services.bitmagnet) requires;
  in {
    wants = requires;
    after = requires;
  };

  services.bitmagnet = {
    enable = true;
    package = pkgs.unstable.bitmagnet;
  };
  sops.secrets."bitmagnet/tmdb_api_key" = {};
  sops.templates."bitmagnet.env".content = ''
    TMDB_API_KEY=${config.sops.placeholder."bitmagnet/tmdb_api_key"}
  '';
  systemd.services.bitmagnet.serviceConfig = {
    DynamicUser = lib.mkForce false;
    ExecStart = lib.mkForce "${config.services.bitmagnet.package}/bin/bitmagnet worker run --keys http_server --keys queue_server";
    EnvironmentFile = config.sops.templates."bitmagnet.env".path;
  };
  users.users.bitmagnet.uid = bitmagnetUid;
  users.groups.bitmagnet.gid = bitmagnetUid;

  containers.rtorrent = {
    bindMounts."/var/run/postgresql" = {
      hostPath = "/run/postgresql/";
      isReadOnly = false;
    };
    bindMounts."/var/lib/bitmagnet" = {
      hostPath = "/var/lib/bitmagnet/";
      isReadOnly = false;
    };
    inherit specialArgs;
    config = { config, pkgs, lib, ... }: {
      users.users.bitmagnet.uid = bitmagnetUid;
      users.groups.bitmagnet.gid = bitmagnetUid;

      services.bitmagnet = {
        enable = true;
        package = pkgs.unstable.bitmagnet;
        useLocalPostgresDB = false;
        settings = {
          dht_crawler = {
            save_files_threshold = 500;
            save_torrents = true;
            save_torrents_root = "/var/lib/bitmagnet/torrents";
          };
        };
      };
      systemd.services.bitmagnet.serviceConfig = {
        DynamicUser = lib.mkForce false;
        ExecStart = lib.mkForce "${config.services.bitmagnet.package}/bin/bitmagnet worker run --keys dht_crawler";
      };
    };
  };
}
