{ config, lib, pkgs, ... }:
let
  available = pkg: lib.optional pkg.meta.available pkg;
in {
  options.isz.quentin.imaging.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.isz.quentin.enable;
  };

  config = lib.mkIf config.isz.quentin.imaging.enable (lib.mkMerge [
    {
      home.packages = with pkgs; [
        exiftool
        libjpeg
        libjpeg_turbo
      ];
      home.file.".ExifTool_config".text = ''
        %Image::ExifTool::UserDefined::Options = (
            LargeFileSupport => 1,
        );
      '';
    }
    (lib.mkIf config.isz.graphical {
      home.packages = with pkgs; [
        feh
        graphicsmagick_q16
        imagemagickBig
        #makeicns
        libicns
        libraw # Replaces dcraw
        nsxiv
        opencv
        rawtherapee-snapshot
        #broken wxSVG
        libwmf
        drawio
      ] ++ lib.optionals pkgs.stdenv.isLinux [
        darktable
        digikam
        inkscape-with-extensions
        krita
        scribus
        boxy-svg
        kdePackages.kolourpaint
        swayimg
      ] ++ (available libresprite)
      ++ (available yeetgif)
      ++ (available gimp-with-plugins);
    })
  ]);
}
