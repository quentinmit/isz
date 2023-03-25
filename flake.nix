{
  inputs = {
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    unstable.url = "nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/release-22.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-index-database.url = "github:Mic92/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    nix-npm-buildpackage.url = "github:serokell/nix-npm-buildpackage";
  };
  outputs = { self, nixpkgs, unstable, sops-nix, nix-npm-buildpackage, flake-compat, home-manager, ... }:
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
          home-manager.nixosModules.home-manager
          sops-nix.nixosModules.sops
        ];
      };
    };
}
