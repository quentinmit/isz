{ pkgs, lib, nixpkgs, self, ... }:

{
  imports = [
    "${nixpkgs}/nixos/modules/services/monitoring/telegraf.nix"
    self.nixosModules.telegraf
  ];

  config = {
    nixpkgs.hostPlatform = "x86_64-linux";
    # TODO: Merge with base/default.nix, somehow?
    networking.hostName = "steamdeck";
    networking.domain = "isz.wtf";

    isz.telegraf = {
      enable = true;
      intelRapl = true;
      amdgpu = true;
      powerSupply = true;
    };
  };
}
