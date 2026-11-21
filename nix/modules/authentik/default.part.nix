{ inputs, ... }:
{
  imports = [
    inputs.authentik.nixosModules.default
    ./blueprint-install.nix
    ./nginx.nix
  ];
}
