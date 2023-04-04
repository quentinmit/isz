{
  inputs = {
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "nixpkgs/nixos-22.11";
    unstable.url = "nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-index-database.url = "github:Mic92/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    darwin.url = "github:lnl7/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = { self, darwin, nixpkgs, unstable, sops-nix, flake-compat, flake-utils, home-manager, nixos-hardware, ... }@args:
    let
      overlay = final: prev: {
        pkgsNativeGnu64 = import nixpkgs { system = "x86_64-linux"; };
        unstable = import unstable { inherit (prev) system; config.allowUnfree = true; };
      };
      # Overlays-module makes "pkgs.unstable" available in configuration.nix
      overlayModule = { config, pkgs, ... }: {
        nixpkgs.overlays = [
          overlay
          ./nix/pkgs/overlays.nix
        ];
      };
      specialArgs = args // {
        channels = { inherit nixpkgs unstable; };
      };
    in (flake-utils.lib.eachDefaultSystem (system:
      let pkgs = (
            import nixpkgs {
              inherit system;
              overlays = [
                (import ./nix/pkgs/all-packages.nix)
                (import ./nix/pkgs/overlays.nix)
              ];}).pkgs;
      in {
        legacyPackages = pkgs;
      })) // {
        nixosConfigurations.workshop = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          inherit specialArgs;
          modules = [
            overlayModule
            ./workshop/configuration.nix
          ];
        };
        nixosConfigurations.bedroom-pi = nixpkgs.lib.nixosSystem {
          inherit specialArgs;
          modules = [
            {
              nixpkgs.hostPlatform = { system = "aarch64-linux"; };
              #nixpkgs.buildPlatform = { system = "x86_64-linux"; config = "x86_64-unknown-linux-gnu"; };
            }
            overlayModule
            ./bedroom/configuration.nix
          ];
        };
        darwinConfigurations.mac = darwin.lib.darwinSystem {
          system = "x86_64-darwin";
          inherit specialArgs;
          modules = [
            overlayModule
            ./mac/configuration.nix
          ];
        };
    };
}
