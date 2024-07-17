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
  };
}
