{ nixpkgs, system, modules, self, specialArgs ? {}, ... }:

let
  inherit system;
  inherit (nixpkgs) lib;
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
        [
          "options.systemd.globalEnvironment"
          "options.systemd.package"
          "options.systemd.paths"
          "options.systemd.slices"
          "options.systemd.sockets"
          "options.systemd.targets"
          "options.systemd.timers"
          "options.systemd.mounts"
          "options.systemd.automounts"
          "options.systemd.units"
          "options.systemd.services"
          "config.systemd.units"
        ]
      )
      (onlyFields
        "${nixpkgs}/nixos/modules/config/users-groups.nix"
        [
          "options.users.users"
          "options.users.groups"
        ]
      )
      self.overlayModule
      ({ lib, config, pkgs, ... }: {
        options = with lib; {
          system.path = mkOption {
            internal = true;
          };
        };
        config = {
          system.path = let
            systemdUnits = pkgs.symlinkJoin {
              name = "systemd-system";
              paths = builtins.map (v: v.unit) (builtins.attrValues eval.config.systemd.units);
            };
          in pkgs.runCommandLocal "sysext-path" {} ''
            mkdir $out
            mkdir -p $out/usr/lib/systemd
            ln -s ${systemdUnits} $out/usr/lib/systemd/system
          '';
        };
      })
    ] ++ modules;
    specialArgs = {
      standalone = true;
    } // specialArgs;
  };
in eval // {
  inherit (eval._module.args) pkgs;
}
