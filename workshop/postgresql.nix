{ config, pkgs, lib, ... }:

{
  options = with lib; {
    isz.postgresql.newPackage = mkOption {
      default = null;
      type = types.nullOr types.package;
    };
  };
  config = {
    # Configure postgres
    services.postgresql = {
      enable = true;
      enableJIT = true;
      package = pkgs.postgresql_15;
      initdbArgs = [
        "--encoding"
        "UTF8"
      ];
      settings = lib.mkMerge [
        {
          max_locks_per_transaction = 256;
        }
        (lib.mkIf config.boot.zfs.enabled {
          full_page_writes = false;
          wal_init_zero = false;
          wal_recycle = false;
        })
      ];
    };
    services.postgresqlBackup = {
      enable = true;
      startAt = "*-*-* 05:15:00";
      compression = "zstd";
      compressionLevel = 9;
    };
    environment.systemPackages = let
      newPostgres = config.isz.postgresql.newPackage;
      cfg = config.services.postgresql;
    in lib.mkIf (newPostgres != null) [
      (pkgs.writeShellScriptBin "upgrade-pg-cluster" ''
        set -eux
        # XXX it's perhaps advisable to stop all services that depend on postgresql
        systemctl stop postgresql

        export NEWDATA="/var/lib/postgresql/${newPostgres.psqlSchema}"

        export NEWBIN="${newPostgres}/bin"

        export OLDDATA="${cfg.dataDir}"
        export OLDBIN="${cfg.package}/bin"

        install -d -m 0700 -o postgres -g postgres "$NEWDATA"
        cd "$NEWDATA"
        sudo -u postgres $NEWBIN/initdb -D "$NEWDATA" ${lib.concatStringsSep " " cfg.initdbArgs}

        sudo -u postgres $NEWBIN/pg_upgrade \
          --old-datadir "$OLDDATA" --new-datadir "$NEWDATA" \
          --old-bindir $OLDBIN --new-bindir $NEWBIN \
          "$@"
      '')
    ];
  };
}
