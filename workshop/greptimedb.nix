{ config, lib, pkgs, ... }:
{
  services.greptimedb = {
    enable = true;
  };
}
