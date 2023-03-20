{
  outputs = { self, nixpkgs }: {
    nixosConfigurations.workshop = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./workshop/configuration.nix ];
    };
  };
}
