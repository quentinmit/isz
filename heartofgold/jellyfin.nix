{ config, pkgs, lib, ... }:
{
  services.jellyfin = {
    enable = true;
  };
}
