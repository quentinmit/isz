{ config, pkgs, lib, ... }:
let
  cfg = config.programs.cargo;
  tomlFormat = pkgs.formats.toml {};
  needed = !(lib.versionAtLeast config.home.version.release "26.05");
in {
  options = with lib; {
    programs.cargo = lib.optionalAttrs needed {
      enable = mkEnableOption "cargo";
      settings = mkOption {
        inherit (tomlFormat) type;
        default = {};
      };
    };
  };
  config = lib.mkIf (needed && cfg.enable) {
    home.file.".cargo/config.toml".source = tomlFormat.generate "cargo.toml" cfg.settings;
  };
}
