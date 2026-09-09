{ config, pkgs, lib, ... }:
{
  config = {
    isz.syncoid.sinks = {
      workshop.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJp0JhnfZevlSxn5DSVOaybntyM1OkNLKOzZi50yL+yX"
      ];
      atlas.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICpQWTeqqoTiy1fk4zU0YiAKTAeqkgHHeY30ERcBvzqB"
      ];
      goddard.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE3CAEQevvfOrY4YwwuRLROHOp68Eho8uFHhr0oK9mNq"
      ];
    };
  };
}
