{ config, pkgs, lib, ... }:
let
  cfg = config.programs.tio;
  format = pkgs.formats.ini {};
in {
  options.programs.tio = with lib; {
    enable = mkEnableOption "tio";
    settings = mkOption {
      inherit (format) type;
      default = {};
      example = {
        default = {
          baudrate = 9600;
          databits = 8;
          parity = "none";
          stopbits = 1;
        };
      };
      description = "tio settings";
    };
  };
  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.tio ];
    xdg.configFile."tio/config".source = format.generate "tioconfig" cfg.settings;
  };
}
