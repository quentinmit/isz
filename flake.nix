{
  inputs = {
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "nixpkgs/nixos-22.11";
    unstable.url = "nixpkgs/nixos-unstable-small";
    #"github:quentinmit/nixpkgs/xquartz";
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
    nur-mweinelt.url = "github:mweinelt/nur-packages";
    nur-mweinelt.inputs.nixpkgs.follows = "nixpkgs";
    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
    deploy-rs.inputs.flake-compat.follows = "flake-compat";
    deploy-rs.inputs.utils.follows = "flake-utils";
  };
  outputs = { self, darwin, nixpkgs, unstable, sops-nix, flake-compat, flake-utils, home-manager, nixos-hardware, deploy-rs, ... }@args:
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
      let inherit ((
            import nixpkgs {
              inherit system;
              overlays = [
                overlay
                (import ./nix/pkgs/all-packages.nix)
                (import ./nix/pkgs/overlays.nix)
              ];})) pkgs;
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
        hmModules = {
          base = import ./nix/home/base.nix;
        };
        deploy.nodes.workshop = {
          sshUser = "root";
          hostname = "workshop.isz.wtf";
          profiles.system.path = deploy-rs.lib.${self.nixosConfigurations.workshop.pkgs.system}.activate.nixos self.nixosConfigurations.workshop;
        };
        deploy.nodes.bedroom-pi = {
          sshUser = "root";
          hostname = "bedroom-pi.isz.wtf";
          profiles.system.path = deploy-rs.lib.${self.nixosConfigurations.bedroom-pi.pkgs.system}.activate.nixos self.nixosConfigurations.bedroom-pi;
        };
        deploy.remoteBuild = true;
        checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
    };
}
