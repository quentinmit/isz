{ lib, pkgs, config, ... }:
with lib;
let
  inherit (config.services.grafana) kind;
  dashboardFormat = pkgs.formats.json {};
  freeformType = dashboardFormat.type;
  intervalType = types.either
    types.int
    (types.strMatching "^(-?[0-9]+(\.[0-9]+)?)(ms|[Mwdhmsy])");
  kindSubmodule = kind: modules: types.submoduleWith {
    shorthandOnlyDefinesConfig = true;
    modules = [{
      options.kind = mkOption {
        type = types.uniq (types.enum [kind]);
        default = kind;
      };
    }] ++ toList modules;
  };
  kindType = type: config.services.grafana.kind.${type};
  kindsType = types: lib.types.oneOf (lib.map (x: config.services.grafana.kind.${x}) types);
  VariableOptionType = types.submodule {
    text = mkOption {
      type = types.str;
      default = "";
    };
    value = mkOption {
      type = types.str;
      default = "";
    };
  };
in {
  options.services.grafana.kind = mkOption {
    type = types.attrsOf types.optionType;
    default = {};
  };
  config.services.grafana.kind = {
    AnnotationQuery = kindSubmodule "AnnotationQuery" {
      options.spec = {
        query = mkOption {
          type = kindType "DataQuery";
        };
        enable = mkOption {
          type = types.bool;
          default = true;
        };
        hide = mkOption {
          type = types.bool;
          default = false;
        };
        iconColor = mkOption {
          type = types.str;
          default = "";
        };
        name = mkOption {
          type = types.str;
          default = "";
        };
        builtIn = mkOption {
          type = types.bool;
          default = false;
        };
      };
    };
    DataQuery = kindSubmodule "DataQuery" {
      options = {
        datasource.name = mkOption {
          type = types.str;
        };
        group = mkOption {
          type = types.str;
        };
        version = mkOption {
          type = types.str;
          default = "v0";
        };
        spec = mkOption {
          type = types.attrsOf types.anything;
          default = {};
        };
      };
    };
    Dashboard = types.submodule ({ name, ... }: {
      options = {
        annotations = mkOption {
          type = types.listOf (kindType "AnnotationQuery");
          default = [{
            kind = "AnnotationQuery";
            spec = {
              builtIn = true;
              enable = true;
              hide = true;
              iconColor = "rgba(0, 211, 255, 1)";
              name = "Annotations & Alerts";
              query = {
                datasource.name = "-- Grafana --";
                group = "grafana";
                kind = "DataQuery";
              };
            };
          }];
        };
        cursorSync = mkOption {
          type = types.enum ["Off" "Crosshair" "Tooltip"];
          default = "Off";
        };
        editable = mkOption {
          type = types.bool;
          default = true;
        };
        elements = mkOption {
          type = types.attrsOf (kindsType ["Panel" "LibraryPanel"]);
          default = {};
        };
        layout = mkOption {
          type = kindsType [
            "GridLayout"
            "RowsLayout"
            "AutoGridLayout"
            "TabsLayout"
          ];
          default.kind = "GridLayout";
        };
        links = mkOption {
          type = types.listOf freeformType; # TODO
          default = [];
        };
        liveNow = mkOption {
          type = types.bool;
          default = false;
          description = ''
            When set to `true`, the dashboard redraws panels at an interval matching the pixel width. This keeps data “moving left” regardless of the query refresh rate. This setting helps avoid dashboards presenting stale live data.
          '';
        };
        preload = mkOption {
          type = types.bool;
          default = false;
          description = ''
            When set to `true`, the dashboard loads all panels when the dashboard is loaded.
          '';
        };
        tags = mkOption {
          type = types.listOf types.str;
          default = [];
        };
        timeSettings = {
          timezone = mkOption {
            type = types.str;
            default = "browser";
          };
          from = mkOption {
            type = types.str;
            default = "now-6h";
          };
          to = mkOption {
            type = types.str;
            default = "now";
          };
          autoRefresh = mkOption {
            type = types.either (types.enum [""]) intervalType;
            default = "";
          };
          autoRefreshIntervals = mkOption {
            type = types.listOf intervalType;
            default = [
              "5s"
              "10s"
              "30s"
              "1m"
              "5m"
              "15m"
              "30m"
              "1h"
              "2h"
              "1d"
            ];
          };
          hideTimepicker = mkOption {
            type = types.bool;
            default = false;
          };
          fiscalYearStartMonth = mkOption {
            type = types.ints.between 0 11;
            default = 0;
          };
        };
        title = mkOption {
          type = types.str;
          default = name;
        };
        variables = mkOption {
          type = types.listOf (kindsType [
            "QueryVariable"
            "CustomVariable"
          ]);
          default = [];
        };
      };
    });
    GridLayout = kindSubmodule "GridLayout" {
      options.spec.items = mkOption {
        type = types.listOf (kindType "GridLayoutItem");
        default = [];
      };
    };
    GridLayoutItem = kindSubmodule "GridLayoutItem" {
      options.spec = {
        x = mkOption {
          type = types.int;
        };
        y = mkOption {
          type = types.int;
        };
        width = mkOption {
          type = types.int;
        };
        height = mkOption {
          type = types.int;
        };
        element = mkOption {
          type = kindType "ElementReference";
        };
      };
    };
    ElementReference = kindSubmodule "ElementReference" {
      options.name = mkOption {
        type = types.str;
      };
    };
    AutoGridLayout = kindSubmodule "AutoGridLayout" {
      options.spec = {
        maxColumnCount = mkOption {
          type = types.int;
          default = 3;
        };
        columnWidthMode = mkOption {
          type = types.enum ["narrow" "standard" "wide" "custom"];
          default = "standard";
        };
	      # columnWidth?: number
	      rowHeightMode = mkOption {
          type = types.enum ["short" "standard" "tall" "custom"];
          defailt = "standard";
        };
	      # rowHeight?: number
	      fillScreen = mkOption {
          type = types.bool;
          default = false;
        };
        items = mkOption {
          type = types.listOf (kindType "AutoGridLayoutItem");
          default = [];
        };
      };
    };
    QueryVariable = kindSubmodule "QueryVariable" {
      options.spec = {
        name = mkOption {
          type = types.str;
        };
        current = mkOption {
          type = VariableOptionType;
          default = {};
        };
        label = mkOption {
          type = types.str;
          default = "";
        };
        hide = mkOption {
          type = types.enum ["dontHide" "hideLabel" "hideVariable" "inControlsMenu"];
          default = "dontHide";
        };
        refresh = mkOption {
          type = types.enum ["never" "onDashboardLoad" "onTimeRangeChanged"];
          default = "never";
        };
        skipUrlSync = mkOption {
          type = types.bool;
          default = false;
        };
        description = mkOption {
          type = types.str;
          default = "";
        };
        query = mkOption {
          type = kindType "DataQuery";
        };
        regex = mkOption {
          type = types.str;
          default = "";
        };
        sort = mkOption {
          type = types.enum ["disabled" "alphabeticalAsc" "alphabeticalDesc" "numericalAsc" "numericalDesc" "alphabeticalCaseInsensitiveAsc" "alphabeticalCaseInsensitiveDesc" "naturalAsc" "naturalDesc"];
          default = "disabled";
        };
        multi = mkOption {
          type = types.bool;
          default = false;
        };
        includeAll = mkOption {
          type = types.bool;
          default = false;
        };
      };
    };
    CustomVariable = kindSubmodule "CustomVariable" {
      options.spec = {
        name = mkOption {
          type = types.str;
        };
        query = mkOption {
          type = types.str;
        };
        current = mkOption {
          type = VariableOptionType;
          default = {};
        };
        options = mkOption {
          type = types.listOf VariableOptionType;
          default = [];
        };
        multi = mkOption {
          type = types.bool;
          default = false;
        };
        includeAll = mkOption {
          type = types.bool;
          default = false;
        };
      };
    };
    Panel = kindSubmodule "Panel" {
      options.spec = {
        id = mkOption {
          type = types.int;
        };
        title = mkOption {
          type = types.str;
          default = "";
        };
        description = mkOption {
          type = types.str;
          default = "";
        };
        links = mkOption {
          type = types.listOf (types.submodule {
            options = {
              title = mkOption {
                type = types.str;
              };
              url = mkOption {
                type = types.str;
              };
              targetBlank = mkOption {
                type = types.bool;
                default = false;
              };
            };
          });
          default = [];
        };
        data = mkOption {
          type = kindType "QueryGroup";
        };
        vizConfig = mkOption {
          type = kindType "VizConfig";
        };
        transparent = mkOption {
          type = types.bool;
          default = false;
        };
      };
    };
    QueryGroup = kindSubmodule "QueryGroup" {
      options = {
        queries = mkOption {
          type = types.listOf (kindType "PanelQuery");
          default = [];
        };
        transformations = mkOption {
          type = types.listOf (kindType "Transformation");
          default = [];
        };
        queryOptions = mkOption {
          type = types.attrsOf types.anything; # TODO
          default = {};
        };
      };
    };
    PanelQuery = kindSubmodule "PanelQuery" {
      query = mkOption {
        type = kindType "DataQuery";
      };
      refId = mkOption {
        type = types.str;
        default = "A";
      };
      hidden = mkOption {
        type = types.bool;
        default = false;
      };
    };
    Transformation = types.anything; # TODO
    VizConfig = kindSubmodule "VizConfig" {
      options.group = mkOption {
        type = types.str;
      };
      options.version = mkOption {
        type = types.str;
      };
      options.spec = {
        options = mkOption {
          type = types.attrsOf types.anything;
          default = {};
        };
        fieldConfig.defaults = mkOption {
          type = types.attrsOf types.anything; # TODO
          default = {};
        };
        fieldConfig.overrides = mkOption {
          type = types.listOf (types.submodule {
            options = {
              __systemRef = mkOption {
                type = types.str;
                default = "";
              };
              matcher.id = mkOption {
                type = types.str;
                default = "";
              };
              matcher.options = mkOption {
                type = types.anything;
              };
              properties = mkOption {
                type = types.listOf (types.submodule {
                  options.id = mkOption {
                    type = types.str;
                    default = "";
                  };
                  options.value = mkOption {
                    type = types.anything;
                  };
                });
                default = [];
              };
            };
          });
        };
      };
    };
  };
}
