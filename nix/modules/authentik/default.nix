{ authentik, ... }:
{
  imports = [
    authentik.nixosModules.default
    ./blueprint-install.nix
  ];
}
