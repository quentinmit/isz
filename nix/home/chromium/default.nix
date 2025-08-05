{ config, lib, ... }:
let
  cfg = config.programs.chromium;
in {
  options = with lib; {
    programs.chromium.gaiaConfigFile = mkOption {
      type = types.nullOr types.path;
      default = null;
    };
  };
  config = lib.mkIf (cfg.gaiaConfigFile != null) {
    programs.chromium.commandLineArgs = [
      "--gaia-config=${cfg.gaiaConfigFile}"
    ];
  };
}
