{ config, lib, pkgs, ... }:
let
format = pkgs.formats.json {};
operatorType = lib.types.submodule ({ name, config, ... }: {
  options = with lib; {
    type = mkOption {
      type = types.enum ["simple" "regexp" "list" "network" "lists"];
      default = "simple";
    };
    operand = mkOption {
      type = types.str;
      default = name;
    };
    data = mkOption {
      type = types.str;
      default = "";
    };
    sensitive = mkOption {
      type = types.bool;
      default = false;
    };
    list = mkOption {
      type = types.nullOr (types.listOf operatorType);
      default = null;
    };
  };
});
ruleType = lib.types.submodule ({ name, config, ... }: {
  options = with lib; {
    name = mkOption {
      type = types.str;
      default = name;
    };
    description = mkOption {
      type = types.str;
      default = "";
    };
    action = mkOption {
      type = types.enum ["allow" "deny"];
      default = "allow";
    };
    list = mkOption {
      type = with types; attrsOf (coercedTo str (data: {
        inherit data;
      }) operatorType);
    };
    operator = mkOption {
      type = operatorType;
      default = {
        type = "list";
        operand = "list";
        list = attrValues config.list;
      };
    };
  };
});
in {
  options = with lib; {
    isz.opensnitch.rules = mkOption {
      type = types.attrsOf ruleType;
      default = {};
    };
  };
  config = {
    isz.opensnitch.rules = {
      nsncd-DNS.list = {
        # Dynamic UID: uid = "${config.users.users.nscd.uid}";
        protocol = "udp";
        "dest.port" = "53";
        "process.path" = "${lib.getBin pkgs.nsncd}/bin/nsncd";
      };
      chrome.list = {
        "process.path" = "${lib.getBin pkgs.google-chrome}/share/google/chrome/chrome";
      };
      avahi.list = lib.mkIf config.services.avahi.enable {
        protocol = "udp";
        "dest.port" = "5353";
        "process.path" = "${config.services.avahi.package}/sbin/avahi-daemon";
      };
    };
    services.opensnitch = {
      enable = true;
      rules = lib.mapAttrs (name: value: {
        inherit (value) name description action operator;
        enabled = true;
        duration = "always";
        precedence = false;
        nolog = false;
      }) config.isz.opensnitch.rules;
    };
  };
}
