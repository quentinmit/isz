{ config, lib, pkgs, ... }:
{
  options = with lib; {
    isz.quentin.theme.enable = mkOption {
      default = config.isz.quentin.enable && pkgs.stdenv.isLinux;
      defaultText = literalExpression "config.isz.quentin.enable && pkgs.stdenv.isLinux";
      type = types.bool;
    };
  };
  config = lib.mkIf config.isz.quentin.theme.enable {
    # KDE likes to replace the symlink with a text file.
    home.file.${config.gtk.gtk2.configLocation}.force = true;
    gtk = {
      enable = true;
      theme.name = "Breeze";
      cursorTheme.name = "breeze_cursors";
      cursorTheme.size = 24;
      iconTheme.name = "breeze-dark";
      font.name = "Noto Sans";
      font.size = lib.mkDefault 11;
      # Plasma will try to overwrite ~/.gtkrc-2.0
      # KDE >= 5.27.2 won't do it if the file doesn't exist, but either way, just use a different path.
      gtk2.configLocation = "${config.xdg.configHome}/gtk-2.0/gtkrc";
      gtk2.extraConfig = ''
        gtk-enable-animations=1
        gtk-primary-button-warps-slider=0
        gtk-toolbar-style=3
        gtk-menu-images=1
        gtk-button-images=1
      '';
      gtk3.extraConfig = {
        gtk-application-prefer-dark-theme = true;
        gtk-button-images = true;
        gtk-decoration-layout = "icon:minimize,maximize,close";
        gtk-enable-animations = true;
        gtk-menu-images = true;
        gtk-modules = "colorreload-gtk-module:window-decorations-gtk-module";
        gtk-primary-button-warps-slider = false;
        gtk-toolbar-style = 3;
      };
      gtk4.extraConfig = {
        gtk-application-prefer-dark-theme = true;
        gtk-decoration-layout = "icon:minimize,maximize,close";
        gtk-enable-animations = true;
        gtk-primary-button-warps-slider = false;
      };
    };
  };
}
