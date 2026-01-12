{ config, lib, pkgs, ... }:
let
  cfg = config.isz.telegraf.sysctl;
in {
  options = with lib; {
    isz.telegraf.sysctl = {
      integers = mkOption {
        type = types.listOf types.str;
        default = [];
      };
      strings = mkOption {
        type = types.listOf types.str;
        default = [];
      };
    };
  };
  config = {
    isz.telegraf.sysctl = lib.mkIf pkgs.stdenv.isLinux {
      strings = [
        "kernel.arch"
        "kernel.osrelease"
        "kernel.version"
      ];
      integers = [
        "kernel.tainted"
      ];
    };
    services.telegraf.extraConfig = let
      inputs = lib.concatMap (data_type: let
        names = cfg."${data_type}s";
      in
        lib.optional (names != []) {
          alias = "sysctl_${data_type}s";
          files = lib.map (name: "/proc/sys/${lib.replaceString "." "/" name}") names;
          name_override = "sysctl";
          file_path_tag = "path";
          data_format = "value";
          inherit data_type;
        }
      ) ["string" "integer"];
    in {
      inputs.file = inputs;
      processors.starlark = lib.mkIf (inputs != []) [{
        alias = "sysctl";
        namepass = ["sysctl"];
        source = ''
          def apply(metric):
            variable = metric.tags.pop("path").removeprefix("/proc/sys/").replace("/", ".")
            metric.fields[variable] = metric.fields.pop("value")
            return [metric]
        '';
      }];
    };
  };
}
