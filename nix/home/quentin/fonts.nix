{ config, lib, pkgs, ... }:
{
  options.isz.quentin.fonts.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.isz.quentin.enable;
  };

  config = lib.mkIf config.isz.quentin.fonts.enable {
    home.packages = with pkgs; [
      # + default fonts in plasma.nix
      aileron
      fragment-mono
      helvetica-neue-lt-std
      bakoma_ttf
      vistafonts
      gyre-fonts
      libertinus
      (google-fonts.override {
        fonts = [
          "Pathway Gothic One"
        ];
      })
      apple-fonts.SF-Pro
      apple-fonts.SF-Mono
      apple-fonts.SF-Compact
      apple-fonts.NY
    ];
  };
}
