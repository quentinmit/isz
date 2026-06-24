{ config, pkgs, lib, ... }:

{
  config = {
    # Configure postgres
    isz.postgresql.enable = true;
    services.postgresql = {
      package = pkgs.postgresql_15;
      settings.max_locks_per_transaction = 256;
      settings.max_connections = 300;
    };
  };
}
