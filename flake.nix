{
  inputs = {
    unstable.url = "nixpkgs/nixos-unstable";
    sops-nix.url = "github:Mic92/sops-nix";
  };
  outputs = { self, nixpkgs, unstable, sops-nix }:
    let
      overlay = final: prev: {
        unstable = import unstable { inherit (prev) system; config.allowUnfree = true; };
      };
      # Overlays-module makes "pkgs.unstable" available in configuration.nix
      overlayModule = ({ config, pkgs, ... }: { nixpkgs.overlays = [ overlay ]; });
    in {
      nixosConfigurations.workshop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs.channels = { inherit nixpkgs unstable };
        modules = [
          overlayModule
          ./workshop/configuration.nix
          sops-nix.nixosModules.sops
        ];
      };
    };
}
