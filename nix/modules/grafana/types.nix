{ lib, pkgs, ... }:
with lib;
rec {
  dashboardFormat = pkgs.formats.json {};
  Interval = types.strMatching "^$|([0-9]+[smhd])";
  Panel = types.submodule {
    freeformType = dashboardFormat.type;
    options = {
      type = mkOption {
        type = types.strMatching ".+";
      };
      title = mkOption {
        type = with types; nullOr str;
        default = null;
      };
      description = mkOption {
        type = with types; nullOr str;
        default = "";
      };
      gridPos = mkOption {
        type = with types; nullOr GridPos;
        default = null;
      };
      links = mkOption {
        type = with types; nullOr DashboardLink;
        default = [];
      };
      repeat = mkOption {
        type = with types; nullOr str;
        default = null;
        description = "Name of template variable to repeat for.";
      };
      repeatDirection = mkOption {
        type = types.enum ["h" "v"];
        default = "h";
        description = ''
            Direction to repeat in if 'repeat' is set.
					  "h" for horizontal, "v" for vertical.
          '';
      };
      interval = mkOption {
        type = with types; nullOr Interval;
        default = null;
      };
      options = mkOption {
        type = dashboardFormat.type;
        default = {};
      };
      fieldConfig = mkOption {
        type = FieldConfigSource;
        default = {};
      };
    };
  };
  FieldConfigSource = types.submodule {
    options = {
      defaults = mkOption {
        type = FieldConfig;
        default = {};
      };
      overrides = mkOption {
        type = with types; listOf (submodule {
          options = {
            matcher = mkOption {
              type = MatcherConfig;
            };
            properties = mkOption {
              type = types.listOf DynamicConfigValue;
            };
          };
        });
        default = [];
      };
    };
  };
  FieldConfig = types.submodule {
    freeformType = dashboardFormat.type;
    options = {
      displayName = mkOption {
        type = with types; nullOr str;
        default = null;
      };
      unit = mkOption {
        type = with types; nullOr str;
        default = null;
      };
      min = mkOption {
        type = with types; nullOr number;
        default = null;
      };
      max = mkOption {
        type = with types; nullOr number;
        default = null;
      };
      color = mkOption {
        type = with types; nullOr FieldColor;
        default = {
          mode = "palette-classic";
        };
      };
    };
  };
  FieldColor = types.submodule {
    options = {
      mode = mkOption {
        type = with types; either (enum ["thresholds" "palette-classic" "palette-saturated" "continuous-GrYlRd" "fixed"]) str;
      };
      fixedColor = mkOption {
        type = with types; nullOr str;
        default = null;
      };
      seriesBy = mkOption {
        type = with types; nullOr (enum ["min" "max" "last"]);
        default = null;
      };
    };
  };
  MatcherConfig = types.submodule {
    options = {
      id = mkOption {
        type = types.str;
        default = "";
      };
      options = mkOption {
        type = dashboardFormat.type;
      };
    };
  };
  DynamicConfigValue = types.submodule {
    options = {
      id = mkOption {
        type = types.str;
        default = "";
      };
      value = mkOption {
        type = dashboardFormat.type;
      };
    };
  };
  GridPos = types.submodule {
    options = {
      h = mkOption {
        type = types.ints.positive;
        default = 8;
      };
      w = mkOption {
        type = types.ints.between 1 24;
        default = 12;
      };
      x = mkOption {
        type = types.ints.between 0 23;
        default = 0;
      };
      y = mkOption {
        type = types.ints.unsigned;
        default = 0;
      };
    };
  };
  DashboardLink = dashboardFormat.type;
}
