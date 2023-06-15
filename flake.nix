{
  inputs = {
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "nixpkgs/nixos-22.11";
    unstable.url = "nixpkgs/nixos-unstable";
    #"github:quentinmit/nixpkgs/xquartz";
    # Remove pin when moving to nixos 23.05
    home-manager.url = "github:nix-community/home-manager/6142193635ecdafb9a231bd7d1880b9b7b210d19";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-index-database.url = "github:Mic92/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.inputs.nixpkgs-stable.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    darwin.url = "github:quentinmit/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    nur-mweinelt.url = "github:mweinelt/nur-packages";
    nur-mweinelt.inputs.nixpkgs.follows = "nixpkgs";
    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
    deploy-rs.inputs.flake-compat.follows = "flake-compat";
    deploy-rs.inputs.utils.follows = "flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.flake-utils.follows = "flake-utils";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    cargo2nix.url = "github:cargo2nix/cargo2nix/release-0.11.0";
    cargo2nix.inputs.flake-utils.follows = "flake-utils";
    cargo2nix.inputs.nixpkgs.follows = "nixpkgs";
    cargo2nix.inputs.rust-overlay.follows = "rust-overlay";
  };
  outputs = { self, darwin, nixpkgs, unstable, sops-nix, flake-compat, flake-utils, home-manager, nixos-hardware, deploy-rs, cargo2nix, ... }@args:
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
      overlays = [
        overlay
        (import ./nix/pkgs/all-packages.nix)
        (import ./nix/pkgs/overlays.nix)
        cargo2nix.overlays.default
      ];
      # Overlays-module makes "pkgs.unstable" available in configuration.nix
      overlayModule = { config, pkgs, ... }: {
        nixpkgs.overlays = overlays;
      };
      specialArgs = args // {
        channels = { inherit nixpkgs unstable; };
      };
      findModules = dir:
        builtins.concatLists (builtins.attrValues (builtins.mapAttrs
          (name: type:
            if type == "regular" then [{
              name = builtins.elemAt (builtins.match "(.*)\\.nix" name) 0;
              value = dir + "/${name}";
            }] else if (
              builtins.readDir (dir + "/${name}"))
            ? "default.nix" then [{
              inherit name;
              value = dir + "/${name}";
            }] else
              findModules (dir + "/${name}")) (builtins.readDir dir)));
    in (flake-utils.lib.eachDefaultSystem (system:
      let inherit ((
            import nixpkgs {
              inherit system;
              inherit overlays;
            })) pkgs;
      in {
        legacyPackages = pkgs;
        devShells.esphome = import ./workshop/esphome/shell.nix { inherit pkgs; };
      })) // {
        inherit overlayModule;
        nixosConfigurations = nixpkgs.lib.genAttrs [
          "workshop"
          "bedroom-pi"
        ] (name: nixpkgs.lib.nixosSystem {
          inherit specialArgs;
          modules = (builtins.attrValues self.nixosModules) ++ [
            overlayModule
            ./${name}/configuration.nix
          ];
        });
        darwinConfigurations.mac = darwin.lib.darwinSystem {
          system = "x86_64-darwin";
          inherit specialArgs;
          modules = (builtins.attrValues self.darwinModules) ++ [
            overlayModule
            ./mac/configuration.nix
          ];
        };
        homeConfigurations.steamdeck-deck = home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            system = "x86_64-linux";
          };
          modules = [
            overlayModule
            ./steamdeck/deck.nix
          ];
          extraSpecialArgs = specialArgs;
        };
        nixosModules = builtins.listToAttrs (findModules ./nix/modules);
        darwinModules = builtins.listToAttrs (findModules ./nix/darwin) // {
          # Modules that work on both nixos and nix-darwin
          inherit (self.nixosModules)
            base
            telegraf
          ;
        };
        homeModules = builtins.listToAttrs (findModules ./nix/home);
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
        steamdeckSys = import ./steamdeck/sys.nix { inherit self nixpkgs specialArgs; };
        steamdeckSysext = import ./nix/sysext.nix {
          inherit self nixpkgs specialArgs;
          system = "x86_64-linux";
          modules = [
            ./steamdeck/configuration.nix
          ];
        };
        deploy.nodes.steamdeck = {
          hostname = "steamdeck.isz.wtf";
          sshOpts = [ "source" "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh;" ];
          #profiles.sys = {
          #  sshUser = "root";
          #  path = deploy-rs.lib.x86_64-linux.activate.custom self.steamdeckSys "./bin/nix-sys";
          #};
          profiles.deck = {
            sshUser = "deck";
            path = deploy-rs.lib.${self.homeConfigurations.steamdeck-deck.pkgs.system}.activate.home-manager self.homeConfigurations.steamdeck-deck;
          };
        };
        deploy.remoteBuild = true;
        checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
    };
}
