{ self, importFlakeModule, ... }:
{ lib, ... }: let
  findModules = dir:
    builtins.concatLists (builtins.attrValues (builtins.mapAttrs
      (name: type:
        if type == "regular" then (
          if lib.hasSuffix ".part.nix" name then
            [{
              name = lib.removeSuffix ".part.nix" name;
              value = importFlakeModule (dir + "/${name}");
            }]
          else if lib.hasSuffix ".nix" name then
            [{
              name = lib.removeSuffix ".nix" name;
              value = dir + "/${name}";
            }]
          else null
        ) else if type == "directory" then (let
          contents = builtins.readDir (dir + "/${name}");
          in if contents ? "default.nix" then [{
            inherit name;
            value = dir + "/${name}";
          }] else if contents ? "default.part.nix" then [{
            inherit name;
            value = importFlakeModule (dir + "/${name}/default.part.nix");
          }]
          else
            (map
              (e: e // {name = "${name}/${e.name}";})
              (findModules (dir + "/${name}"))
            )
        ) else []
      ) (builtins.readDir dir)));
  defaultNixosModules = builtins.listToAttrs (findModules ../nix/modules);
  defaultDarwinModules = builtins.listToAttrs (findModules ../nix/darwin);
  defaultHomeModules = builtins.listToAttrs (findModules ../nix/home);
in {
  config = lib.mkMerge [
    {
      flake.nixosModules = defaultNixosModules;
      flake.darwinModules = defaultDarwinModules;
      flake.homeModules = defaultHomeModules;
    }
    {
      flake.nixosModules.overlays = { ... }: {
        nixpkgs.overlays = [
          self.overlays.default
        ];
      };
      flake.nixosModules.default.imports =
        (builtins.attrValues defaultNixosModules) ++ [
          self.nixosModules.overlays
        ];
      flake.darwinModules.default.imports = builtins.attrValues defaultDarwinModules;
      flake.homeModules.default.imports = builtins.attrValues defaultHomeModules;
    }
  ];
}