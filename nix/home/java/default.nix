{ config, lib, pkgs, ... }:
let
  cfg = config.java.userPrefs;
  prefsFormat = pkgs.formats.json {};
  prefsFile = prefsFormat.generate "userPrefs.json" cfg;
in {
  options = with lib; {
    java.userPrefs = mkOption {
      type = with types; let
        valueType = oneOf [
          str
          (attrsOf valueType)
        ] // {
          description = "Java preference value";
        };
      in valueType;
      default = {};
    };
  };
  config = {
    home.activation.configure-java-userprefs = lib.mkIf (cfg != {}) (lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${pkgs.json2prefs}/bin/json2prefs < ${prefsFile}
    '');
  };
}
