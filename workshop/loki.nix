{ config, lib, pkgs, ... }:
let
  inherit (config.services.loki) dataDir;
in {
  systemd.services.loki.serviceConfig = {
    RuntimeDirectory = "loki";
    UMask = "0007";
  };
  services.loki = {
    enable = true;
    configuration = {
      auth_enabled = false; # Disable multi-tenancy
      server.http_listen_network = "unix";
      server.http_listen_address = "/run/loki/loki.sock";
      server.http_listen_port = 80; # Will be appended to the Unix socket path (https://github.com/grafana/dskit/issues/475)
      # Unix sockets are not supported for gRPC because Loki doesn't know how to advertise them in the ring.
      #server.grpc_listen_network = "unix";
      #server.grpc_listen_address = "/run/loki/loki,sock";
      server.grpc_listen_address = "127.0.0.1";
      frontend_worker.frontend_address = "127.0.0.1:9095";
      common.replication_factor = 1;
      common.path_prefix = dataDir;
      common.ring = {
        kvstore.store = "inmemory";
        instance_interface_names = ["lo"];
        instance_addr = "127.0.0.1";
      };
      query_scheduler.scheduler_ring.instance_addr = "127.0.0.1";
      schema_config.configs = [{
        from = "2024-01-01";
        store = "tsdb";
        object_store = "filesystem";
        schema = "v13";
        index.period = "24h";
      }];
      compactor = {
        working_directory = "${dataDir}/retention";
        compaction_interval = "10m";
        retention_enabled = true;
        retention_delete_delay = "2h";
        retention_delete_worker_count = 50;
        delete_request_store = "filesystem";
      };
      storage_config.filesystem.directory = "${dataDir}/chunks";
      limits_config = {
        retention_period = "744d";
      };
    };
  };
  users.users."${config.services.nginx.user}".extraGroups = [ config.services.loki.user ];
  services.nginx = {
    upstreams.loki.servers."unix:/run/loki/loki.sock:80" = {};
    virtualHosts."loki.isz.wtf" = {
      forceSSL = true;
      enableACME = true;
      locations."/" = {
        proxyPass = "http://loki";
        proxyWebsockets = true;
      };
    };
  };
}
