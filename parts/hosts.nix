{ self, inputs, ... }:
{ lib, ... }:
{
  config = lib.mkMerge [
    {
      easy-hosts.hosts = lib.genAttrs [
        "atlas.comclub.org"
        "bedroom-pi"
        "build-arm"
        "droid"
        "goddard"
        "goddard/afs"
        "heartofgold"
        "mnemosyne"
        "rascsi"
        "uconsole"
        "workshop"
      ] (name: {
        path = ../${name}/configuration.nix;
        modules = [
          self.nixosModules.default
          inputs.disko.nixosModules.disko
        ];
      });
    }
    {
      easy-hosts.hosts.uconsole-unstable = {
        nixpkgs = inputs.unstable;
        path = ../uconsole/configuration.nix;
        modules = [
          self.nixosModules.base
          self.nixosModules.sshd-sops
          self.nixosModules.telegraf
          {
            nixpkgs.overlays = [
              self.overlays.multiVersion
              self.overlays.new
              self.overlays.stable
              self.overlays.unstable
              self.overlays.mosh-server-upnp
            ];
          }
        ];
      };
      easy-hosts.hosts.mac = {
        class = "darwin";
        path = ../mac/configuration.nix;
        modules = [
          self.darwinModules.default
          self.nixosModules.overlays
        ];
      };
      flake.nixosConfigurations.atlas = self.nixosConfigurations."atlas.comclub.org";
    }
  ];
}