{ lib, pkgs, ... }:
{
  imports = [
    ./syslog.nix
    ./mikrotik.nix
    ./netflow.nix
  ];
  config = {
    isz.vector.enable = true;
    systemd.services.vector.serviceConfig.RuntimeDirectory = "vector";
  };
}
