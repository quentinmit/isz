{ pkgs, ... }:
let
  rustPkgs = pkgs.rustBuilder.makePackageSet {
    rustVersion = "1.64.0";
    packageFun = import ./Cargo.nix;
    # packageOverrides = pkgs: pkgs.rustBuilder.overrides.all; # Implied, if not specified
  };
in (rustPkgs.workspace.systemd-metrics {}).bin
