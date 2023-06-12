{ nixpkgs, nix-sys-repo, self, ... }:

let
  system = "x86_64-linux";
  lib = nixpkgs.lib;
  pkgs = import nixpkgs {
    inherit system;
  };
  nix-sys = (import nix-sys-repo {
    inherit pkgs;
  });
  onlyFields = file: names: { pkgs, ... } @ args: (
    let orig = lib.applyModuleArgsIfFunction "" (import file) args;
    in filterAttrsByPath orig names
  );
  filterAttrsByPath = orig: names: lib.foldl' lib.recursiveUpdate {} (
    builtins.map (
      name:
      let
        path = lib.splitString "." name;
      in
        lib.setAttrByPath path (lib.getAttrFromPath path orig)
    ) names);
  eval = lib.evalModules {
    modules = [
      "${nixpkgs}/nixos/modules/misc/extra-arguments.nix"
      "${nixpkgs}/nixos/modules/misc/nixpkgs.nix"
      (onlyFields
        "${nixpkgs}/nixos/modules/tasks/network-interfaces.nix"
        [ "options.networking.hostName" "options.networking.domain" ]
      )
      (onlyFields
        "${nixpkgs}/nixos/modules/system/boot/systemd.nix"
        [ "options.systemd.globalEnvironment" "options.systemd.package" "options.systemd.paths" "options.systemd.slices" "options.systemd.sockets" "options.systemd.targets" "options.systemd.timers" "options.systemd.mounts" "options.systemd.automounts" "options.systemd.units" "options.systemd.services" "config.systemd.units" ]
      )
      (onlyFields
        "${nixpkgs}/nixos/modules/config/users-groups.nix"
        [ "options.users.users" "options.users.groups" ]
      )
      "${nixpkgs}/nixos/modules/services/monitoring/telegraf.nix"
      #"${nixpkgs}/nixos/modules/system/etc/etc.nix"
      #"${nixpkgs}/nixos/modules/config/system-environment.nix"
      self.overlayModule
      self.nixosModules.telegraf
      {
        nixpkgs.hostPlatform = "x86_64-linux";
        networking.domain = "isz.wtf";
        isz.telegraf.enable = true;
      }
    ];
    specialArgs = {
      standalone = true;
    };
  };
  generateSystemd = name: config:
    pkgs.writeText "${name}" config.config.systemd.units."${name}".text;
  manifest = {
    symlink = {
      "/etc/systemd/system/telegraf.service" = {
        path = generateSystemd "telegraf.service" eval;
      };
    };
  };
in nix-sys.nix-sys.override {
  manifest = pkgs.writeText "manifest.json" (builtins.toJSON manifest);
  nixsys-preprocess = pkgs.callPackage "${nix-sys-repo}/preprocess/package.nix" {
    version = "8107";
  };
}
