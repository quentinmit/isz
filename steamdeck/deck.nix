{ config, pkgs, self, ... }:

{
  imports = with self.homeModules; [
    base
  ];

  home.username = "deck";
  home.homeDirectory = "/home/deck";

  home.stateVersion = "23.05";

  home.packages = with pkgs; [
    htop
    wget
    ncdu
    onboard
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

  programs.bash = {
    shellAliases = {
      emacs = "flatpak run org.gnu.emacs";
    };

    initExtra = ''
      # Added by ProtonUp-Qt on 24-10-2022 22:29:50
      if [ -d "/home/deck/stl/prefix" ]; then export PATH="$PATH:/home/deck/stl/prefix"; fi
    '';
  };
}
