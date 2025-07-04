{
  inputs = {
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "nixpkgs/nixos-25.05";
    nixpkgs-23_05.url = "nixpkgs/nixos-23.05";
    unstable.url = "nixpkgs/nixos-unstable";
    #"github:quentinmit/nixpkgs/xquartz";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-index-database.url = "github:Mic92/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    darwin.url = "github:LnL7/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    nur-mweinelt.url = "github:mweinelt/nur-packages";
    nur-mweinelt.inputs.nixpkgs.follows = "nixpkgs";
    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
    deploy-rs.inputs.flake-compat.follows = "flake-compat";
    deploy-rs.inputs.utils.follows = "flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    cargo2nix.url = "github:cargo2nix/cargo2nix/release-0.11.0";
    cargo2nix.inputs.flake-utils.follows = "flake-utils";
    cargo2nix.inputs.flake-compat.follows = "flake-compat";
    cargo2nix.inputs.nixpkgs.follows = "nixpkgs";
    cargo2nix.inputs.rust-overlay.follows = "rust-overlay";
    plasma-manager.url = "github:pjones/plasma-manager";
    plasma-manager.inputs.nixpkgs.follows = "nixpkgs";
    plasma-manager.inputs.home-manager.follows = "home-manager";
    py-profinet.url = "github:quentinmit/py-profinet/asyncio";
    py-profinet.inputs.nixpkgs.follows = "nixpkgs";
    py-profinet.inputs.flake-utils.follows = "flake-utils";
    Jovian-NixOS.url = "github:Jovian-Experiments/Jovian-NixOS";
    Jovian-NixOS.inputs.nixpkgs.follows = "nixpkgs";
    nixgl.url = "github:guibou/nixGL";
    nixgl.inputs.nixpkgs.follows = "nixpkgs";
    nixgl.inputs.flake-utils.follows = "flake-utils";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    authentik.url = "github:nix-community/authentik-nix";
    authentik.inputs.nixpkgs.follows = "nixpkgs";
    authentik.inputs.flake-utils.follows = "flake-utils";
    authentik.inputs.flake-compat.follows = "flake-compat";
    bluechips.url = "github:quentinmit/bluechips";
    bluechips.inputs.nixpkgs.follows = "nixpkgs";
    bluechips.inputs.flake-utils.follows = "flake-utils";
    lanzaboote.url = "github:nix-community/lanzaboote/v0.4.2";
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";
    lanzaboote.inputs.flake-compat.follows = "flake-compat";
    lanzaboote.inputs.pre-commit-hooks-nix.follows = "";
    lanzaboote.inputs.rust-overlay.follows = "rust-overlay";
    mosh-server-upnp.url = "github:quentinmit/mosh-server-upnp/nix-flake-update";#"github:arcnmx/mosh-server-upnp";
    mosh-server-upnp.inputs.nixpkgs.follows = "nixpkgs";
    gradle2nix.url = "github:tadfisher/gradle2nix/v2";
    gradle2nix.inputs.nixpkgs.follows = "nixpkgs";
    gradle2nix.inputs.flake-utils.follows = "flake-utils";
    oom-hardware.url = "github:robertjakub/oom-hardware";
    nixos-inventree.url = "github:quentinmit/nixos-inventree/isz";
    nixos-inventree.inputs.nixpkgs.follows = "unstable";
    nixos-inventree.inputs.flake-utils.follows = "flake-utils";
    chemacs2nix.url = "github:league/chemacs2nix";
    chemacs2nix.inputs.home-manager.follows = "home-manager";
    chemacs2nix.inputs.pre-commit-hooks.follows = "";
  };
  outputs = { self, darwin, nixpkgs, nixpkgs-23_05, unstable, sops-nix, flake-compat, flake-utils, home-manager, nixos-hardware, deploy-rs, cargo2nix, py-profinet, Jovian-NixOS, bluechips, mosh-server-upnp, gradle2nix, ... }@args:
    let
      overlay = final: prev: {
        pkgsNativeGnu64 = import nixpkgs { system = "x86_64-linux"; };
        unstable = import unstable {
          system = final.system or final.stdenv.system;
          inherit (final) config;
          overlays = [
            self.overlays.new
            #self.overlays.stable
            self.overlays.unstable
            py-profinet.overlays.default
            Jovian-NixOS.overlays.default
            bluechips.overlays.default
          ];
        };
        inherit (gradle2nix.packages.${final.system or "x86_64-linux"}) gradle2nix;
      };
      overlays = [
        overlay
        self.overlays.new
        self.overlays.stable
        self.overlays.stable-darwin
        self.overlays.mosh-server-upnp
        cargo2nix.overlays.default
        deploy-rs.overlays.default
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
            }]
            else
              (map
                (e: e // {name = "${name}/${e.name}";})
                (findModules (dir + "/${name}"))
              )
          ) (builtins.readDir dir)));
    in (flake-utils.lib.eachDefaultSystem (system:
      let inherit ((
            import nixpkgs {
              inherit system;
              inherit overlays;
              config.allowUnfree = true;
            })) pkgs;
      in {
        legacyPackages = pkgs;
        devShells.esphome = import ./workshop/esphome/shell.nix { pkgs = pkgs.unstable; };
        devShells.pico-sdk = pkgs.mkShell {
          buildInputs = with pkgs; [
            gcc-arm-embedded
            picotool
            pico-sdk-full
            cmake python3  # build requirements for pico-sdk
            udisks         # Interact with bootloader filesystem
            tio            # terminal program to interface with serial
          ];
          shellHook = ''
            export PICO_SDK_PATH=${pkgs.pico-sdk-full}/lib/pico-sdk
          '';
        };
      })) // {
        inherit overlayModule;
        inherit self args;
        overlays.new = import ./nix/pkgs/all-packages.nix;
        overlays.stable = import ./nix/pkgs/overlays.nix;
        overlays.stable-darwin = import ./nix/pkgs/darwin-overlays.nix;
        overlays.mosh-server-upnp = final: prev: {
          mosh-server-upnp = final.callPackage mosh-server-upnp.flakes.args.packages.mosh-server-upnp {};
        };
        overlays.default = nixpkgs.lib.composeManyExtensions overlays;
        overlays.unstable = import ./nix/pkgs/unstable-overlays.nix;
        nixosConfigurations = let
          inherit (nixpkgs) lib;
        in (lib.genAttrs [
          "workshop"
          "bedroom-pi"
          "droid"
          "goddard"
          "heartofgold"
          "rascsi"
        ] (name: lib.nixosSystem {
          inherit specialArgs;
          modules = (builtins.attrValues self.nixosModules) ++ [
            overlayModule
            ./${name}/configuration.nix
          ];
        })) // {
          uconsole = unstable.lib.nixosSystem {
            inherit specialArgs;
            modules = [ #(builtins.attrValues self.nixosModules) ++ [
              self.nixosModules.base
              self.nixosModules.sshd-sops
              self.nixosModules.telegraf
              ({
                nixpkgs.overlays = [
                  overlay
                  self.overlays.new
                  self.overlays.stable
                  self.overlays.unstable
                  self.overlays.mosh-server-upnp
                ];
              })
              ./uconsole/configuration.nix
            ];
          };
        };
        darwinConfigurations.mac = darwin.lib.darwinSystem {
          system = "x86_64-darwin";
          inherit specialArgs;
          modules = (builtins.attrValues self.darwinModules) ++ [
            overlayModule
            (final: prev: {
              nixpkgs-23_05 = import nixpkgs-23_05 {
                inherit (final) system config;
              };
            })
            ./mac/configuration.nix
          ];
        };
        homeConfigurations.deck = home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            system = "x86_64-linux";
          };
          modules = (builtins.attrValues self.homeModules) ++ [
            overlayModule
            ./steamdeck/deck.nix
          ];
          extraSpecialArgs = specialArgs;
        };
        nixosModules = builtins.listToAttrs (findModules ./nix/modules);
        darwinModules = builtins.listToAttrs (findModules ./nix/darwin);
        homeModules = builtins.listToAttrs (findModules ./nix/home);
        deploy.nodes.droid = {
          sshUser = "root";
          hostname = "droid.isz.wtf";
          profiles.system.path = deploy-rs.lib.${self.nixosConfigurations.droid.pkgs.system}.activate.nixos self.nixosConfigurations.droid;
        };
        deploy.nodes.workshop = {
          sshUser = "root";
          hostname = "workshop.mgmt.isz.wtf";
          profiles.system.path = deploy-rs.lib.${self.nixosConfigurations.workshop.pkgs.system}.activate.nixos self.nixosConfigurations.workshop;
        };
        deploy.nodes.bedroom-pi = {
          sshUser = "root";
          hostname = "bedroom-pi.mgmt.isz.wtf";
          profiles.system.path = deploy-rs.lib.${self.nixosConfigurations.bedroom-pi.pkgs.system}.activate.nixos self.nixosConfigurations.bedroom-pi;
        };
        deploy.nodes.heartofgold = {
          sshUser = "root";
          hostname = "heartofgold.isz.wtf";
          profiles.system.path = deploy-rs.lib.${self.nixosConfigurations.workshop.pkgs.system}.activate.nixos self.nixosConfigurations.heartofgold;
        };
        deploy.nodes.uconsole = {
          sshUser = "root";
          hostname = "uconsole.isz.wtf";
          profiles.system.path = deploy-rs.lib.${self.nixosConfigurations.uconsole.pkgs.system}.activate.nixos self.nixosConfigurations.uconsole;
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
          # sshOpts doesn't work because of https://github.com/NixOS/nix/issues/8292
          #sshOpts = [ "source" "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh;" ];
          #profiles.sys = {
          #  sshUser = "root";
          #  path = deploy-rs.lib.x86_64-linux.activate.custom self.steamdeckSys "./bin/nix-sys";
          #};
          profiles.deck = {
            sshUser = "deck";
            path = deploy-rs.lib.${self.homeConfigurations.deck.pkgs.system}.activate.home-manager self.homeConfigurations.steamdeck-deck;
          };
        };
        checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
    };
}
