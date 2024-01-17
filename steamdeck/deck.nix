{ config, pkgs, lib, self, Jovian-NixOS, nixgl, ... }:

{
  home.username = "deck";
  home.homeDirectory = "/home/deck";

  home.stateVersion = "23.05";

  nixpkgs.overlays = [
    Jovian-NixOS.overlays.default
    nixgl.overlay
    (final: prev: {
      inherit (final.unstable) gamescope;
    })
  ];

  home.packages = with pkgs; [
    # Network
    netsurf.browser
    qgis-ltr
    remmina
    wireshark
    x11vnc

    # Productivity
    abiword
    apostrophe
    calibre
    foliate
    kile
    libsForQt5.ghostwriter
    marktext
    onlyoffice-bin
    retext
    rnote
    setzer
    sigil
    texmaker
    texstudio
    texworks
    xournalpp

    # Graphics
    darktable
    digikam
    freecad
    gimp-with-plugins
    inkscape-with-extensions
    krita
    scribus

    # Games
    dosbox
    gcn64tools

    # Development
    cutecom
    ghidra-bin
    iaito

    # Multimedia
    easyeffects
    helvum
    libsForQt5.kdenlive
    #natron
    qpwgraph
    timidity
    vlc
    vmpk

    # Radio
    fldigi
    flrig
    gpredict
    qsstv
    sdrangel
    viking

    # Utilities
    appeditor
    bottles-unwrapped
    CuboCore.corekeyboard
    #fingerterm
    gnome.dconf-editor
    inotify-tools
    jstest-gtk
    kwalletcli
    kwalletmanager
    pkgs.nixgl.nixGLIntel
    telegraf
    unar
  ];

  programs.onboard.enable = true;

  systemd.user.services.sdgyrodsu = {
    Unit.Description = "Cemuhook DSU server for the Steam Deck Gyroscope";
    Unit.WantedBy = [ "graphical-session.target" ];
    Service = {
      ExecStart = "${pkgs.sdgyrodsu}/bin/sdgyrodsu";
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
    };
  };

  services.syncthing = {
    enable = true;
    tray = {
      enable = true;
      package = pkgs.syncthingtray;
    };
  };

  programs.bash = {
    shellAliases = {
      emacs = "flatpak run org.gnu.emacs";
    };

    initExtra = ''
      # Added by ProtonUp-Qt on 24-10-2022 22:29:50
      if [ -d "/home/deck/stl/prefix" ]; then export PATH="$PATH:/home/deck/stl/prefix"; fi
    '';
  };

  # Set a basic PATH for sshd
  pam.sessionVariables = {
    PATH = "/home/deck/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/usr/local/sbin:/usr/local/bin:/usr/bin";
    inherit (config.home.sessionVariables) LOCALE_ARCHIVE_2_27;
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
  isz.plasma.enable = true;
  programs.plasma.shortcuts = {
    "khotkeys"."{e521ea71-a8c8-4e23-9b72-4c9ca63c6874}" = "Meta+K";
  };
  programs.plasma.configFile = {
    "kcminputrc"."Mouse"."X11LibInputXAccelProfileFlat" = true;
    "kdeglobals"."General"."BrowserApplication" = "com.google.Chrome.desktop";
#       "khotkeysrc"."Data_4"."Comment" = "Comment";
#       "khotkeysrc"."Data_4"."DataCount" = 1;
#       "khotkeysrc"."Data_4"."Enabled" = true;
#       "khotkeysrc"."Data_4"."Name" = "Quentin";
#       "khotkeysrc"."Data_4"."SystemGroup" = 0;
#       "khotkeysrc"."Data_4"."Type" = "ACTION_DATA_GROUP";
#       "khotkeysrc"."Data_4Conditions"."Comment" = "";
#       "khotkeysrc"."Data_4Conditions"."ConditionsCount" = 0;
#       "khotkeysrc"."Data_4_1"."Comment" = "Comment";
#       "khotkeysrc"."Data_4_1"."Enabled" = true;
#       "khotkeysrc"."Data_4_1"."Name" = "Open Onboard";
#       "khotkeysrc"."Data_4_1"."Type" = "SIMPLE_ACTION_DATA";
#       "khotkeysrc"."Data_4_1Actions"."ActionsCount" = 1;
#       "khotkeysrc"."Data_4_1Actions0"."Arguments" = "";
#       "khotkeysrc"."Data_4_1Actions0"."Call" = "org.onboard.Onboard.Keyboard.ToggleVisible";
#       "khotkeysrc"."Data_4_1Actions0"."RemoteApp" = "org.onboard.Onboard";
#       "khotkeysrc"."Data_4_1Actions0"."RemoteObj" = "/org/onboard/Onboard/Keyboard";
#       "khotkeysrc"."Data_4_1Actions0"."Type" = "DBUS";
#       "khotkeysrc"."Data_4_1Conditions"."Comment" = "";
#       "khotkeysrc"."Data_4_1Conditions"."ConditionsCount" = 0;
#       "khotkeysrc"."Data_4_1Triggers"."Comment" = "Simple_action";
#       "khotkeysrc"."Data_4_1Triggers"."TriggersCount" = 1;
#       "khotkeysrc"."Data_4_1Triggers0"."Key" = "Meta+K";
#       "khotkeysrc"."Data_4_1Triggers0"."Type" = "SHORTCUT";
#       "khotkeysrc"."Data_4_1Triggers0"."Uuid" = "{e521ea71-a8c8-4e23-9b72-4c9ca63c6874}";
  };

  xdg.configFile."kate/lspclient/settings.json".text = lib.generators.toJSON {} {
    servers.nix = {
      command = ["${pkgs.unstable.nil}/bin/nil"];
      url = "https://github.com/oxalica/nil";
      highlightingModeRegex = "^Nix$";
    };
  };
}
