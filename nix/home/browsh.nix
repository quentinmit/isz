{ config, pkgs, lib, ... }:
let
  cfg = config.programs.browsh;
  tomlFormat = pkgs.formats.toml {};
in {
  options = with lib; {
    programs.browsh = {
      enable = mkEnableOption "browsh CLI browser";
      package = mkOption {
        type = types.package;
        default = pkgs.browsh;
      };
      firefoxPackage = mkOption {
        type = types.package;
        default = pkgs.firefox;
      };
      finalPackage = mkOption {
        type = types.package;
        readOnly = true;
        description = "Final browsh package that bundles Firefox";
      };
      settings = mkOption {
        inherit (tomlFormat) type;
        default = {};
        description = ''
          Configuration written to
          {file}`$XDG_CONFIG_HOME/.config/browsh/config.toml`.

          See <https://www.brow.sh/docs/config/>
          for the full list of options.
        '';
      };
    };
  };
  config = lib.mkMerge [
    {
      programs.browsh.finalPackage = cfg.package.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          sed -i '/func getFirefoxPath/{n;c\
          return "${lib.getBin cfg.firefoxPackage}/bin/firefox";
          }' src/browsh/firefox_unix.go
        '';
      });
    }
    (lib.mkIf cfg.enable {
      home.packages = [
        cfg.finalPackage
      ];
      xdg.configFile."browsh/config.toml" = lib.mkIf (cfg.settings != {}) {
        source = tomlFormat.generate "browsh-config.toml" cfg.settings;
      };
    })
  ];
}
