{
  outputs = { self, nixpkgs }: {
    nixpkgs.overlays = [
      import ./nix/pkgs/all-packages.nix
    ];
    nixosConfigurations.workshop = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./workshop/configuration.nix ];
    };
  };
}
