{ lib, config, ... }:
let
  cfg = config.services.easyeffects;
  submoduleParentWith = attrs: let
    prev = lib.types.submoduleWith attrs;
  in prev // {
    merge = loc: defs: prev.merge loc ([{ file = ""; value = _: { _module.args.name = lib.mkForce (builtins.elemAt loc (builtins.length loc - 2)); }; }] ++ defs);
    substSubModules = m: submoduleParentWith (attrs // {
      modules = m;
    });
  };
  autoloadSubmodule = submoduleParentWith {
    modules = [({ config, name, ... }: {
      options = with lib; {
        device = mkOption {
          type = types.str;
        };
        device-description = mkOption {
          type = types.str;
        };
        device-profile = mkOption {
          type = types.str;
        };
        preset-name = mkOption {
          type = types.str;
          default = name;
        };
      };
    })];
  };
  autoloadType = lib.types.attrsOf (lib.types.listOf autoloadSubmodule);
in {
  options = with lib; {
    services.easyeffects = {
      autoload.output = mkOption {
        type = autoloadType;
        default = {};
        description = "";
      };
    };
  };
  config = lib.mkIf cfg.enable {
    xdg.configFile = builtins.listToAttrs (
      lib.flatten (
        lib.mapAttrsToList
          (type: presets:
            builtins.map
              (preset: lib.nameValuePair "easyeffects/autoload/${type}/${preset.device}:${preset.device-profile}.json" {text = builtins.toJSON preset;})
            (lib.flatten (builtins.attrValues presets))
          )
          cfg.autoload
      )
    );
  };
}
