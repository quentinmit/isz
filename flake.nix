{
  inputs = {
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    unstable.url = "nixpkgs/nixos-unstable";
    sops-nix.url = "github:Mic92/sops-nix";
    nix-npm-buildpackage.url = "github:serokell/nix-npm-buildpackage";
  };
  outputs = { self, nixpkgs, unstable, sops-nix, nix-npm-buildpackage, flake-compat }:
    let
      overlay = final: prev: {
        unstable = import unstable { inherit (prev) system; config.allowUnfree = true; };
      };
      # Overlays-module makes "pkgs.unstable" available in configuration.nix
      overlayModule = ({ config, pkgs, ... }: {
        nixpkgs.overlays = [
          overlay
          nix-npm-buildpackage.overlays.default
        ];
      });
    in {
      pkgs = (import nixpkgs {
        system = "x86_64-linux";
        overlays = [
        (import ./nix/pkgs/all-packages.nix)
      ];}).pkgs;
      nixosConfigurations.workshop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs.channels = { inherit nixpkgs unstable; };
        modules = [
          overlayModule
          ./workshop/configuration.nix
          sops-nix.nixosModules.sops
        ];
      };
    };
}
