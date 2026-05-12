{ config, lib, pkgs, ... }:
{
  isz.networking.vlans = [983];

  isz.telegraf.macsnmp.targets = [{
    ip = "172.30.98.130";
  }];
}
