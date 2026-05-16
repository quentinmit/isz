{ lib, pkgs, config, ... }:
with lib;
let
  inherit (config.services.grafana) kind;
  dashboardFormat = pkgs.formats.json {};
  freeformType = dashboardFormat.type;
  intervalType = types.either
    types.int
    (types.strMatching "^(-?[0-9]+(\.[0-9]+)?)(ms|[Mwdhmsy])");
  byKind =
    kinds:
    let
      choicesStr = concatMapStringsSep ", " lib.strings.escapeNixIdentifier (attrNames kinds);
      inherit (lib)
        map
        mapAttrsToList
      ;
      inherit (lib.options)
        getFiles
        showFiles
      ;
    in
      lib.mkOptionType {
        name = "byKind";
        description = "attrset with kind one of: ${choicesStr}";
        descriptionClass = "noun";
        check = lib.isAttrs;
        merge =
          loc: defs:
          let
            choice = (head (lib.filter (def: def.value ? kind) defs)).value.kind;
            checkedValueDefs = map (
              def:
              if (def.value.kind or choice) != choice then
                throw "The option `${showOption loc}` is defined both as `${choice}` and `${def.value.kind}`, in ${showFiles (getFiles defs)}."
              else
                def
            ) defs;
          in
        if kinds ? ${choice} then
          (lib.modules.evalOptionValue loc kinds.${choice} checkedValueDefs).value
        else
          throw "The option `${showOption loc}` is defined as ${lib.strings.escapeNixString choice}, but ${lib.strings.escapeNixString choice} is not among the valid choices (${choicesStr}). Value ${choice} was defined in ${showFiles (getFiles defs)}.";
        nestedTypes = kinds;
        functor = {
          name = "byKind";
          type = { kinds, ... }: byKind kinds;
          wrapped = null;
          payload = { inherit kinds; };
          binOp = let
            wrapOptionDecl = option: {
              options = option;
              _file = "<byKind {...}>";
              pos = null;
            };
          in a: b: {
            kinds = a.kinds // b.kinds // mapAttrs (
              kindName: bOpt:
              lib.mergeOptionDecls
                [ kindName ]
                [
                  (wrapOptionDecl a.kinds.${kindName})
                  (wrapOptionDecl bOpt)
                ]
              // {
                # mergeOptionDecls is not idempotent in these attrs:
                declarations = a.kinds.${kindName}.declarations ++ bOpt.declarations;
                declarationPositions = a.kinds.${kindName}.declarationPositions ++ bOpt.declarationPositions;
              }
            ) (builtins.intersectAttrs a.tags b.tags);
          };
        };
      };
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
  kindsType = types: byKind (lib.genAttrs types (x: mkOption { type = config.services.grafana.kind.${x}; default = {}; }));
  VariableOptionType = types.submodule {
    options = {
      text = mkOption {
        type = types.str;
        default = "";
      };
      value = mkOption {
        type = types.str;
        default = "";
      };
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
    Dashboard = kindSubmodule "Dashboard" ({ name, ... }: {
      options.apiVersion = mkOption {
        type = types.uniq (types.enum ["dashboard.grafana.app/v2"]);
        default = "dashboard.grafana.app/v2";
      };
      options.metadata = {
        name = mkOption {
          type = types.str;
          default = lib.last (lib.splitString "/" name);
        };
      };
      options.spec = {
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
    RowsLayout = kindSubmodule "RowsLayout" {
      options.spec.rows = mkOption {
        type = types.listOf (kindType "RowsLayoutRow");
        default = [];
      };
    };
    RowsLayoutRow = kindSubmodule "RowsLayoutRow" {
      options.spec = {
        collapse = mkOption {
          type = types.bool;
          default = false;
        };
        # conditionalRendering?
	      fillScreen = mkOption {
          type = types.bool;
          default = false;
        };
	      hideHeader = mkOption {
          type = types.bool;
          default = false;
        };
        layout = mkOption {
          type = kindsType [
            "AutoGridLayout"
            "GridLayout"
            "RowsLayout"
            "TabsLayout"
          ];
        };
        # repeat?
        title = mkOption {
          type = types.str;
        };
        # variables?
        variables = mkOption {
          type = types.listOf (kindsType [
            "QueryVariable"
            "TextVariable"
            "ConstantVariable"
            "DatasourceVariable"
            "IntervalVariable"
            "CustomVariable"
            "GroupByVariable"
            "AdhocVariable"
            "SwitchVariableKind"
          ]);
          default = [];
        };
      };
    };
    TabsLayout = kindSubmodule "TabsLayout" {
      options.spec.tabs = mkOption {
        type = types.listOf (kindType "TabsLayoutTab");
      };
    };
    TabsLayoutTab = kindSubmodule "TabsLayoutTab" {
      options.spec = {
        # conditionalRendering?
        layout = mkOption {
          type = kindsType [
            "AutoGridLayout"
            "GridLayout"
            "RowsLayout"
            "TabsLayout"
          ];
        };
        # repeat?
        title = mkOption {
          type = types.str;
        };
        # variables?
        variables = mkOption {
          type = types.listOf (kindsType [
            "QueryVariable"
            "TextVariable"
            "ConstantVariable"
            "DatasourceVariable"
            "IntervalVariable"
            "CustomVariable"
            "GroupByVariable"
            "AdhocVariable"
            "SwitchVariableKind"
          ]);
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
          default = "standard";
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
    AutoGridLayoutItem = kindSubmodule "AutoGridLayoutItem" {
      options.spec = {
        element = mkOption {
          type = kindType "ElementReference";
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
          default = 0; # FIXME
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
      options.spec = {
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
      options.spec = {
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
    };
    Transformation = types.anything; # TODO
    VizConfig = kindSubmodule "VizConfig" {
      options.group = mkOption {
        type = types.str;
      };
      options.version = mkOption {
        type = types.str;
        default = "13.0.0";
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
