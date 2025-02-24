{ config, lib, pkgs, ... }:
{
  options.isz.quentin.imaging.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.isz.quentin.enable;
  };

  config = lib.mkIf config.isz.quentin.imaging.enable {
    home.packages = with pkgs; [
      exiftool
      feh
      graphicsmagick_q16
      imagemagickBig
      #makeicns
      libicns
      libjpeg
      libjpeg_turbo
      libraw # Replaces dcraw
      opencv
      rawtherapee
      #broken wxSVG
      (if pkgs.stdenv.isDarwin then gimp else gimp-with-plugins)
      libwmf
      drawio
      yeetgif
    ] ++ lib.optionals pkgs.stdenv.isLinux [
      darktable
      digikam
      inkscape-with-extensions
      krita
      scribus
      boxy-svg
      kdePackages.kolourpaint
    ] ++ (available libresprite);
    home.file.".ExifTool_config".text = ''
      %Image::ExifTool::UserDefined::Options = (
          LargeFileSupport => 1,
      );
    '';
  };
}
