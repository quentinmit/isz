{ config, pkgs, lib, ... }:
{
  config = {
    isz.syncoid.sinks = {
      heartofgold.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFD2hU07Ip7phzEZfkaBJAb8HCzVwNSkLaaxO7Dprg4O"
      ];
      workshop.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAimpn3Kmi/AueDleLIzr314OUYM1uADqLS9uFHlWONA"
      ];
      atlas.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMLnnEI9zK9bAJAaYLhKte0TxPuNMSOOkh8caEWA5O/j"
      ];
      goddard.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIps4DtyjIkE7/fzhosN0iVJRHU8iYTuxZ47Z6QzJlo/"
      ];
    };
  };
}
