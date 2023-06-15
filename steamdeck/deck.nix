{ config, pkgs, self, ... }:

{
  imports = with self.homeModules; [
    base
    onboard
  ];

  home.username = "deck";
  home.homeDirectory = "/home/deck";

  home.stateVersion = "23.05";

  home.packages = with pkgs; [
    htop
    wget
    ncdu
    #fingerterm
    dosbox
    inotify-tools
    timidity
    mosh
    netcat-gnu
    x11vnc
    unar
    telegraf
  ];

  programs.onboard.enable = true;

  programs.bash = {
    shellAliases = {
      emacs = "flatpak run org.gnu.emacs";
    };

    initExtra = ''
      # Added by ProtonUp-Qt on 24-10-2022 22:29:50
      if [ -d "/home/deck/stl/prefix" ]; then export PATH="$PATH:/home/deck/stl/prefix"; fi
    '';
  };
  gtk = {
    enable = true;
    theme.name = "Breeze";
    cursorTheme.name = "breeze_cursors";
    cursorTheme.size = 24;
    iconTheme.name = "breeze-dark";
    font.name = "Noto Sans";
    font.size = 11;
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
  programs.git.lfs.enable = true;
}
