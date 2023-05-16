{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.wireshark;
  wireshark = cfg.package;
in {
  options = {
    programs.wireshark = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = lib.mdDoc ''
          Whether to add Wireshark to the global environment. Add users to the
          'access_bpf' group to allow them to capture packets.
        '';
      };
      package = mkOption {
        type = types.package;
        default = pkgs.wireshark-cli;
        defaultText = literalExpression "pkgs.wireshark-cli";
        description = lib.mdDoc ''
          Which Wireshark package to install in the global environment.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ wireshark ];
  };
}
