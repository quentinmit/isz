{ lib, pkgs, config, options, ...}@args:
let
  cfg = config.isz.telegraf.mikrotik;
in {
  imports = [
    ./api.nix
    ./swos.nix
    ./snmp.nix
  ];
  config = {
    isz.telegraf.interval.mikrotik = lib.mkOptionDefault "30s";
    services.telegraf.extraConfig = {
      processors.starlark = [{
        order = 1000;
        namepass = [ "mikrotik-*" ];
        source = ''
          def apply(m1):
            m2 = deepcopy(m1, track=True)
            m1.tags["influxdb_bucket"] = ""
            m2.tags["greptimedb_database"] = "mikrotik"
            m2.name = m2.name.removeprefix("mikrotik-").replace("/", ":")
            return [m1, m2]
        '';
      }];
    };
  };
}
