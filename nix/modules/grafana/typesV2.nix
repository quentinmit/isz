{ lib, pkgs, config, ... }:
with lib;
let
  dashboardFormat = pkgs.formats.json {};
  freeformType = dashboardFormat.type;
  intervalType = types.either
    types.int
    (types.strMatching "^(-?\d+(?:\.\d+)?)(ms|[Mwdhmsy])");
  kindType = kind: let
    finalType = config.services.grafana.kind.${kind};
  in mkOptionType rec {
    name = "kindType";
    description = "${optionDescriptionPhrase (class: class == "noun") finalType} or ${kind}Kind";
    check = {
      __functor = _self: x:
        if x ? kind || x ? spec then
          ((builtins.attrNames x) == ["kind" "spec"] || (builtins.attrNames x) == ["spec"]) && finalType.check x.spec
        else
          finalType.check x;
      isV2MergeCoherent = true;
    };
    merge = {
      __functor =
        self: loc: defs:
        (self.v2 { inherit loc defs; }).value;
      v2 =
        { loc, defs }:
        let
          finalDefs = (
            map (
              def:
              def
              // {
                value =
                  if x ? kind || x ? spec then
                    def.value.spec
                  else
                    def.value;
              }
            ) defs
          );
          loc' = loc + ["spec"];
          in
            if finalType.merge ? v2 then
              checkV2MergeCoherence loc' finalType (
                let
                  merged = finalType.merge.v2 {
                    loc = loc';
                    defs = finalDefs;
                  };
                in
                  merged // {
                    value = {
                      inherit kind;
                      spec = merged.value;
                    };
                  }
              )
            else
              {
                value = {
                  inherit kind;
                  spec = finalType.merge loc' finalDefs;
                };
                valueMeta = { };
                headError = checkDefsForError check loc' defs;
              };
    };
    emptyValue = { };
    getSubOptions = finalType.getSubOptions;
    getSubModules = finalType.getSubModules;
    typeMerge = t: null;
    functor = defaultFunctor name;
    nestedTypes.finalType = finalType;
  };
  DataQueryKind = types.submodule {
    options = {
      kind = mkOption {
        type = types.enum ["DataQuery"];
        default = "DataQuery";
      };
    };
  };
in {
  options.services.grafana.kind = mkOption {
    type = types.attrsOf types.optionType;
    default = {};
  };
  config.services.grafana.kind = {
    AnnotationQuery = types.submodule {
      options = {
        query = mkOption {
          # DataQuery doesn't behave like a normal kind/spec object.
          type = DataQueryKind;
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
    Dashboard = types.submodule ({ name, ... }: {
      options = {
        annotations = mkOption {
          type = types.listOf (kindType "AnnotationQuery");
          default = [{
            datasource.type = "grafana";
            datasource.uid = "-- Grafana --";
            enable = true;
            hide = true;
            iconColor = "rgba(0, 211, 255, 1)";
            name = "Annotations & Alerts";
            builtIn = true;
            query = {
            };
            target.limit = 100;
            target.matchAny = false;
            target.tags = [];
            target.type = "dashboard";
            type = "dashboard";
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
          type = types.attrsOf (kindTypes ["Panel" "LibraryPanel"]);
          default = {};
        };
        layout = mkOption {
          type = layoutType;
          default = {
            GridLayout.items = [];
          };
        };
        links = mkOption {
          type = listOf freeformType; # TODO
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
            type = intervalType;
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
            type = types.intBetween 0 11;
            default = 0;
          };
        };
        title = mkOption {
          type = types.str;
          default = name;
        };
        variables = mkOption {
          type = types.listOf (kindTypes [
            "QueryVariable"
            "CustomVariable"
          ]);
          default = [];
        };
      };
    });
    CustomVariable = let
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
    in types.submodule {
      options = {
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
  };
}
