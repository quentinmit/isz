{
  inputs = {
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "nixpkgs/nixos-22.11";
    unstable.url = "github:quentinmit/nixpkgs/xquartz";
    # Remove pin when moving to nixos 23.05
    home-manager.url = "github:nix-community/home-manager/6142193635ecdafb9a231bd7d1880b9b7b210d19";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-index-database.url = "github:Mic92/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    darwin.url = "github:quentinmit/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    nur.url = "github:nix-community/NUR";
  };
  outputs = { self, darwin, nixpkgs, unstable, sops-nix, flake-compat, flake-utils, home-manager, nixos-hardware, nur, ... }@args:
    let
      overlay = final: prev: {
        pkgsNativeGnu64 = import nixpkgs { system = "x86_64-linux"; };
        unstable = import unstable {
          inherit (prev) system;
          config.allowUnfree = true;
          overlays = [
            (import ./nix/pkgs/all-packages.nix)
            (import ./nix/pkgs/unstable-overlays.nix)
          ];
        };
      };
      # Overlays-module makes "pkgs.unstable" available in configuration.nix
      overlayModule = { config, pkgs, ... }: {
        nixpkgs.overlays = [
          overlay
          (import ./nix/pkgs/overlays.nix)
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
                overlay
                (import ./nix/pkgs/all-packages.nix)
                (import ./nix/pkgs/overlays.nix)
              ];}).pkgs;
      in {
        legacyPackages = pkgs;
        devShells.esphome = import ./workshop/esphome/shell.nix { inherit pkgs; };
      })) // {
        nixosConfigurations.workshop = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          inherit specialArgs;
          modules = [
            overlayModule
            ./workshop/configuration.nix
            nur.nixosModules.nur
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
