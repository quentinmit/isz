{ config, pkgs, lib, ... }:
let
  cfg = config.programs.onboard;
in {
  options = with lib; {
    programs.onboard = {
      enable = mkEnableOption "Onboard";
      package = mkOption {
        type = types.package;
        default = pkgs.onboard;
      };
      layout = mkOption {
        type = types.str;
        default = "Compact";
      };
      theme = mkOption {
        type = types.str;
        default = "Blackboard";
      };
      colorScheme = mkOption {
        type = types.str;
        default = "Charcoal";
      };
    };
  };
  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    dconf.settings = {
      "org/onboard" = {
        #current-settings-page = 1;
        layout = "${cfg.package}/share/onboard/layouts/${cfg.layout}.onboard";
        schema-version = "2.3";
        #system-theme-associations = "{'HighContrast': 'HighContrast', 'HighContrastInverse': 'HighContrastInverse', 'LowContrast': 'LowContrast', 'ContrastHighInverse': 'HighContrastInverse', 'Default': '', 'Breeze': '/home/deck/.local/share/onboard/themes/Blackboard.theme'}";
        theme = "${cfg.package}/share/onboard/themes/${cfg.theme}.theme";
        use-system-defaults = false;
      };

      "org/onboard/icon-palette" = {
        in-use = false;
      };

      "org/onboard/keyboard" = {
        show-click-buttons = true;
      };

      "org/onboard/theme-settings" = {
        background-gradient = 0.0;
        color-scheme = "${cfg.package}/share/onboard/themes/${cfg.colorScheme}.colors";
        key-fill-gradient = 8.0;
        key-gradient-direction = -3.0;
        key-label-font = "DejaVu Sans";
        key-shadow-size = 0.0;
        key-shadow-strength = 0.0;
        key-size = 90.0;
        key-stroke-gradient = 0.0;
        key-stroke-width = 100.0;
        key-style = "gradient";
        roundrect-radius = 30.0;
      };

      "org/onboard/window" = {
        background-transparency = 10.0;
        docking-enabled = false;
        enable-inactive-transparency = true;
        inactive-transparency-delay = 3.0;
        transparent-background = false;
      };

      "org/onboard/window/landscape" = {
        dock-height = 266;
        height = 266;
        width = 1066;
        x = 177;
        y = 182;
      };
    };
  };
}
