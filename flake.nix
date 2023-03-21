{
  inputs = {
    sops-nix.url = "github:Mic92/sops-nix";
  };
  outputs = { self, nixpkgs, sops-nix }: {
    nixosConfigurations.workshop = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./workshop/configuration.nix
        sops-nix.nixosModules.sops
      ];
    };
  };
}
