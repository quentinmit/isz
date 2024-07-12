{ config, pkgs, lib, ... }:
{
  # Configure speedtest
  sops.secrets."speedtest_influx_password" = {
    owner = "speedtest-influxdb";
  };
  services.speedtest-influxdb = {
    enable = true;
    influxdb = {
      url = "http://influx.isz.wtf:8086/";
      username = "speedtest";
      passwordPath = config.sops.secrets.speedtest_influx_password.path;
      db = "speedtest";
    };
    interval = 3600;
    showExternalIp = true;
    hosts = [
      "comcast"
      "calyx"
    ];
  };
  systemd.services = lib.mapAttrs' (name: dscp: let
    unit = "speedtest-influxdb@${name}";
    table = "speedtest-influxdb-${name}";
    tableFile = pkgs.writeText "${unit}.nft" ''
      table ${table};
      flush table ${table};
      table ip ${table} {
        chain output {
          type filter hook output priority mangle + 5;

          socket cgroupv2 level 3 "system.slice/system-speedtest\x2dinfluxdb.slice/${unit}.service" ip dscp set ${toString dscp};
        }
      }
      table ip6 ${table} {
        chain output {
          type filter hook output priority mangle + 5;

          socket cgroupv2 level 3 "system.slice/system-speedtest\x2dinfluxdb.slice/${unit}.service" drop;
        }
      }
    '';
  in lib.nameValuePair unit {
    overrideStrategy = "asDropin";
    serviceConfig.ExecStartPre = [
      "+${pkgs.nftables}/bin/nft -f ${tableFile}"
    ];
    serviceConfig.ExecStopPost = [
      "+${pkgs.nftables}/bin/nft destroy table ${table}"
    ];
  }) {
    "calyx" = 50;
    "comcast" = 51;
  };
}
