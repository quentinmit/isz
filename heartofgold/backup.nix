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
    isz.syncoid.targets.mnemosyne = {
      pool = "tank";
      sources = [
        "zpool/heartofgold"
      ];
      excludeDatasets = [
        # TODO: Sync media/quentin
        "zpool/heartofgold/media/quentin"
        # TODO: Sync media/media1e
        "zpool/heartofgold/media/media1e"
        # Low priority datasets that aren't worth sending offsite
        "zpool/heartofgold/home/quentin/hog-data"
        "zpool/heartofgold/nix"
        "zpool/heartofgold/var/lib/bitmagnet"
      ];
    };
  };
}
