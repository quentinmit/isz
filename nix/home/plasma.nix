{ config, pkgs, lib, isz, plasma-manager, ... }:
let
  arrayValue = items:
    lib.concatMapStringsSep
      ","
      (builtins.replaceStrings [","] [''\\,''])
      items;
in {
  imports = [
    plasma-manager.homeManagerModules.plasma-manager
  ];
  options = with lib; {
    isz.plasma = {
      enable = mkEnableOption "ISZ plasma configuration";
      subpixelHinting = mkEnableOption "Subpixel hinting";
    };
    services.baloo = {
      indexHiddenFolders = mkEnableOption "Index hidden folders";
      excludeFolders = mkOption {
        type = with types; nullOr (listOf str);
        default = null;
        example = ["$HOME/.config/google-chrome/"];
        description = "Folders to exclude from indexing. Note that $HOME is expanded, so to exclude a folder containing a literal $, escape it as $$.";
      };
    };
  };
  config = lib.mkIf config.isz.plasma.enable {
    services.baloo = {
      indexHiddenFolders = true;
      excludeFolders = [
        "$HOME/.config/google-chrome/"
        "$HOME/.cache/google-chrome/"
      ];
    };
    home.packages = with pkgs; [
      monaco-nerd-fonts
      corefonts
      aileron
      fragment-mono
      helvetica-neue-lt-std
      bakoma_ttf
      vistafonts
      gyre-fonts
      libertinus
      #google-fonts
      apple-fonts.SF-Pro
      apple-fonts.SF-Mono
      apple-fonts.SF-Compact
      apple-fonts.NY
    ] ++ builtins.filter lib.attrsets.isDerivation (builtins.attrValues pkgs.unstable.nerd-fonts);
    fonts.fontconfig.enable = true;
    xdg.configFile."fontconfig/conf.d/10-hack.conf".text = ''
      <?xml version='1.0'?>
      <!DOCTYPE fontconfig SYSTEM 'urn:fontconfig:fonts.dtd'>
      <fontconfig>
        <alias>
          <family>Hack Nerd Font</family>
          <accept>
            <family>Terminess Nerd Font</family>
          </accept>
        </alias>
      </fontconfig>
    '';
    programs.plasma = {
      enable = true;
      workspace = {
        theme = "default";
        colorScheme = "BreezeDark";
        #lookAndFeel = "org.kde.breezedark.desktop";
      };
      shortcuts = {
        "KDE Keyboard Layout Switcher"."Switch to Next Keyboard Layout" = "Meta+Alt+K";
        "kaccess"."Toggle Screen Reader On and Off" = "Meta+Alt+S";
        "kcm_touchpad"."Disable Touchpad" = "Touchpad Off";
        "kcm_touchpad"."Enable Touchpad" = "Touchpad On";
        "kcm_touchpad"."Toggle Touchpad" = "Touchpad Toggle";
        "kded5"."Show System Activity" = "Ctrl+Shift+Esc";
        "kded5"."display" = ["Display" "Meta+P"];
        "kmix"."increase_volume" = "Volume Up";
        "kmix"."decrease_volume" = "Volume Down";
        "kmix"."mute" = "Volume Mute";
        "kmix"."decrease_microphone_volume" = ["Microphone Volume Down" "Meta+Volume Down"];
        "kmix"."increase_microphone_volume" = ["Microphone Volume Up" "Meta+Volume Up"];
        "kmix"."mic_mute" = ["Microphone Mute" "Meta+Volume Mute"];
        "ksmserver"."Halt Without Confirmation" = [ ];
        "ksmserver"."Lock Session" = ["Ctrl+Alt+L" "Meta+L" "Screensaver"];
        "ksmserver"."Log Out" = "Ctrl+Alt+Del";
        "ksmserver"."Log Out Without Confirmation" = [ ];
        "ksmserver"."Reboot Without Confirmation" = [ ];
        "kwin"."Activate Window Demanding Attention" = "Meta+Ctrl+A";
        "kwin"."Decrease Opacity" = [ ];
        "kwin"."Edit Tiles" = "Meta+T";
        "kwin"."Expose" = "Ctrl+F9";
        "kwin"."ExposeAll" = ["Ctrl+F10" "Launch (C)"];
        "kwin"."ExposeClass" = "Ctrl+F7";
        "kwin"."ExposeClassCurrentDesktop" = [ ];
        "kwin"."Increase Opacity" = [ ];
        "kwin"."Kill Window" = "Meta+Ctrl+Esc";
        "kwin"."Move Tablet to Next Output" = [ ];
        "kwin"."MoveMouseToCenter" = "Meta+F6";
        "kwin"."MoveMouseToFocus" = "Meta+F5";
        "kwin"."MoveZoomDown" = [ ];
        "kwin"."MoveZoomLeft" = [ ];
        "kwin"."MoveZoomRight" = [ ];
        "kwin"."MoveZoomUp" = [ ];
        "kwin"."Overview" = "Meta+W";
        "kwin"."Setup Window Shortcut" = [ ];
        "kwin"."Show Desktop" = "Meta+D";
        "kwin"."ShowDesktopGrid" = "Meta+F8";
        "kwin"."Suspend Compositing" = "Alt+Shift+F12";
        "kwin"."Switch One Desktop Down" = [ ];
        "kwin"."Switch One Desktop Up" = [ ];
        "kwin"."Switch One Desktop to the Left" = [ ];
        "kwin"."Switch One Desktop to the Right" = [ ];
        "kwin"."Switch Window Down" = "Meta+Alt+Down";
        "kwin"."Switch Window Left" = "Meta+Alt+Left";
        "kwin"."Switch Window Right" = "Meta+Alt+Right";
        "kwin"."Switch Window Up" = "Meta+Alt+Up";
        "kwin"."Switch to Desktop 1" = "Ctrl+F1";
        "kwin"."Switch to Desktop 10" = [ ];
        "kwin"."Switch to Desktop 11" = [ ];
        "kwin"."Switch to Desktop 12" = [ ];
        "kwin"."Switch to Desktop 13" = [ ];
        "kwin"."Switch to Desktop 14" = [ ];
        "kwin"."Switch to Desktop 15" = [ ];
        "kwin"."Switch to Desktop 16" = [ ];
        "kwin"."Switch to Desktop 17" = [ ];
        "kwin"."Switch to Desktop 18" = [ ];
        "kwin"."Switch to Desktop 19" = [ ];
        "kwin"."Switch to Desktop 2" = "Ctrl+F2";
        "kwin"."Switch to Desktop 20" = [ ];
        "kwin"."Switch to Desktop 3" = "Ctrl+F3";
        "kwin"."Switch to Desktop 4" = "Ctrl+F4";
        "kwin"."Switch to Desktop 5" = [ ];
        "kwin"."Switch to Desktop 6" = [ ];
        "kwin"."Switch to Desktop 7" = [ ];
        "kwin"."Switch to Desktop 8" = [ ];
        "kwin"."Switch to Desktop 9" = [ ];
        "kwin"."Switch to Next Desktop" = [ ];
        "kwin"."Switch to Next Screen" = [ ];
        "kwin"."Switch to Previous Desktop" = [ ];
        "kwin"."Switch to Previous Screen" = [ ];
        "kwin"."Switch to Screen 0" = [ ];
        "kwin"."Switch to Screen 1" = [ ];
        "kwin"."Switch to Screen 2" = [ ];
        "kwin"."Switch to Screen 3" = [ ];
        "kwin"."Switch to Screen 4" = [ ];
        "kwin"."Switch to Screen 5" = [ ];
        "kwin"."Switch to Screen 6" = [ ];
        "kwin"."Switch to Screen 7" = [ ];
        "kwin"."Switch to Screen Above" = [ ];
        "kwin"."Switch to Screen Below" = [ ];
        "kwin"."Switch to Screen to the Left" = [ ];
        "kwin"."Switch to Screen to the Right" = [ ];
        "kwin"."Toggle Night Color" = [ ];
        "kwin"."Toggle Window Raise/Lower" = [ ];
        "kwin"."Walk Through Desktop List" = [ ];
        "kwin"."Walk Through Desktop List (Reverse)" = [ ];
        "kwin"."Walk Through Desktops" = [ ];
        "kwin"."Walk Through Desktops (Reverse)" = [ ];
        "kwin"."Walk Through Windows" = "Alt+Tab";
        "kwin"."Walk Through Windows (Reverse)" = "Alt+Shift+Backtab";
        "kwin"."Walk Through Windows Alternative" = [ ];
        "kwin"."Walk Through Windows Alternative (Reverse)" = [ ];
        "kwin"."Walk Through Windows of Current Application" = "Alt+`";
        "kwin"."Walk Through Windows of Current Application (Reverse)" = "Alt+~";
        "kwin"."Walk Through Windows of Current Application Alternative" = [ ];
        "kwin"."Walk Through Windows of Current Application Alternative (Reverse)" = [ ];
        "kwin"."Window Above Other Windows" = [ ];
        "kwin"."Window Below Other Windows" = [ ];
        "kwin"."Window Close" = "Alt+F4";
        "kwin"."Window Fullscreen" = [ ];
        "kwin"."Window Grow Horizontal" = [ ];
        "kwin"."Window Grow Vertical" = [ ];
        "kwin"."Window Lower" = [ ];
        "kwin"."Window Maximize" = "Meta+PgUp";
        "kwin"."Window Maximize Horizontal" = [ ];
        "kwin"."Window Maximize Vertical" = [ ];
        "kwin"."Window Minimize" = "Meta+PgDown";
        "kwin"."Window Move" = [ ];
        "kwin"."Window Move Center" = [ ];
        "kwin"."Window No Border" = [ ];
        "kwin"."Window On All Desktops" = [ ];
        "kwin"."Window One Desktop Down" = "Meta+Ctrl+Shift+Down";
        "kwin"."Window One Desktop Up" = "Meta+Ctrl+Shift+Up";
        "kwin"."Window One Desktop to the Left" = "Meta+Ctrl+Shift+Left";
        "kwin"."Window One Desktop to the Right" = "Meta+Ctrl+Shift+Right";
        "kwin"."Window One Screen Down" = [ ];
        "kwin"."Window One Screen Up" = [ ];
        "kwin"."Window One Screen to the Left" = [ ];
        "kwin"."Window One Screen to the Right" = [ ];
        "kwin"."Window Operations Menu" = "Alt+F3";
        "kwin"."Window Pack Down" = [ ];
        "kwin"."Window Pack Left" = [ ];
        "kwin"."Window Pack Right" = [ ];
        "kwin"."Window Pack Up" = [ ];
        "kwin"."Window Quick Tile Bottom" = "Meta+Down";
        "kwin"."Window Quick Tile Bottom Left" = [ ];
        "kwin"."Window Quick Tile Bottom Right" = [ ];
        "kwin"."Window Quick Tile Left" = "Meta+Left";
        "kwin"."Window Quick Tile Right" = "Meta+Right";
        "kwin"."Window Quick Tile Top" = "Meta+Up";
        "kwin"."Window Quick Tile Top Left" = [ ];
        "kwin"."Window Quick Tile Top Right" = [ ];
        "kwin"."Window Raise" = [ ];
        "kwin"."Window Resize" = [ ];
        "kwin"."Window Shade" = [ ];
        "kwin"."Window Shrink Horizontal" = [ ];
        "kwin"."Window Shrink Vertical" = [ ];
        "kwin"."Window to Desktop 1" = [ ];
        "kwin"."Window to Desktop 10" = [ ];
        "kwin"."Window to Desktop 11" = [ ];
        "kwin"."Window to Desktop 12" = [ ];
        "kwin"."Window to Desktop 13" = [ ];
        "kwin"."Window to Desktop 14" = [ ];
        "kwin"."Window to Desktop 15" = [ ];
        "kwin"."Window to Desktop 16" = [ ];
        "kwin"."Window to Desktop 17" = [ ];
        "kwin"."Window to Desktop 18" = [ ];
        "kwin"."Window to Desktop 19" = [ ];
        "kwin"."Window to Desktop 2" = [ ];
        "kwin"."Window to Desktop 20" = [ ];
        "kwin"."Window to Desktop 3" = [ ];
        "kwin"."Window to Desktop 4" = [ ];
        "kwin"."Window to Desktop 5" = [ ];
        "kwin"."Window to Desktop 6" = [ ];
        "kwin"."Window to Desktop 7" = [ ];
        "kwin"."Window to Desktop 8" = [ ];
        "kwin"."Window to Desktop 9" = [ ];
        "kwin"."Window to Next Desktop" = [ ];
        "kwin"."Window to Next Screen" = "Meta+Shift+Right";
        "kwin"."Window to Previous Desktop" = [ ];
        "kwin"."Window to Previous Screen" = "Meta+Shift+Left";
        "kwin"."Window to Screen 0" = [ ];
        "kwin"."Window to Screen 1" = [ ];
        "kwin"."Window to Screen 2" = [ ];
        "kwin"."Window to Screen 3" = [ ];
        "kwin"."Window to Screen 4" = [ ];
        "kwin"."Window to Screen 5" = [ ];
        "kwin"."Window to Screen 6" = [ ];
        "kwin"."Window to Screen 7" = [ ];
        "kwin"."view_actual_size" = "Meta+0";
        "kwin"."view_zoom_in" = ["Meta++" "Meta+="];
        "kwin"."view_zoom_out" = "Meta+-";
        "mediacontrol"."mediavolumedown" = [ ];
        "mediacontrol"."mediavolumeup" = [ ];
        "mediacontrol"."nextmedia" = "Media Next";
        "mediacontrol"."pausemedia" = "Media Pause";
        "mediacontrol"."playmedia" = [ ];
        "mediacontrol"."playpausemedia" = "Media Play";
        "mediacontrol"."previousmedia" = "Media Previous";
        "mediacontrol"."stopmedia" = "Media Stop";
        "org.kde.dolphin.desktop"."_launch" = "Meta+E";
        "org.kde.kcalc.desktop"."_launch" = "Launch (1)";
        "org.kde.konsole.desktop"."NewTab" = [ ];
        "org.kde.konsole.desktop"."NewWindow" = [ ];
        "org.kde.konsole.desktop"."_launch" = "Ctrl+Alt+T";
        "org.kde.krunner.desktop"."RunClipboard" = "Alt+Shift+F2";
        "org.kde.krunner.desktop"."_launch" = ["Alt+F2" "Search"];
        "org.kde.plasma.emojier.desktop"."_launch" = ["Meta+." "Meta+Ctrl+Alt+Shift+Space"];
        "org.kde.spectacle.desktop"."ActiveWindowScreenShot" = "Meta+Print";
        "org.kde.spectacle.desktop"."CurrentMonitorScreenShot" = [ ];
        "org.kde.spectacle.desktop"."FullScreenScreenShot" = "Shift+Print";
        "org.kde.spectacle.desktop"."OpenWithoutScreenshot" = [ ];
        "org.kde.spectacle.desktop"."RectangularRegionScreenShot" = "Meta+Shift+Print";
        "org.kde.spectacle.desktop"."WindowUnderCursorScreenShot" = "Meta+Ctrl+Print";
        "org.kde.spectacle.desktop"."_launch" = "Print";
        "org_kde_powerdevil"."Decrease Keyboard Brightness" = "Keyboard Brightness Down";
        "org_kde_powerdevil"."Decrease Screen Brightness" = ["Monitor Brightness Down" "Alt+Volume Down"];
        "org_kde_powerdevil"."Hibernate" = "Hibernate";
        "org_kde_powerdevil"."Increase Keyboard Brightness" = "Keyboard Brightness Up";
        "org_kde_powerdevil"."Increase Screen Brightness" = ["Monitor Brightness Up" "Alt+Volume Up"];
        "org_kde_powerdevil"."PowerDown" = "Power Down";
        "org_kde_powerdevil"."PowerOff" = "Power Off";
        "org_kde_powerdevil"."Sleep" = "Sleep";
        "org_kde_powerdevil"."Toggle Keyboard Backlight" = "Keyboard Light On/Off";
        "org_kde_powerdevil"."Turn Off Screen" = [ ];
        "plasmashell"."activate task manager entry 1" = [ ]; # clear default
        "plasmashell"."activate task manager entry 10" = [ ]; # clear default
        "plasmashell"."activate task manager entry 2" = [ ]; # clear default
        "plasmashell"."activate task manager entry 3" = [ ]; # clear default
        "plasmashell"."activate task manager entry 4" = [ ]; # clear default
        "plasmashell"."activate task manager entry 5" = [ ]; # clear default
        "plasmashell"."activate task manager entry 6" = [ ]; # clear default
        "plasmashell"."activate task manager entry 7" = [ ]; # clear default
        "plasmashell"."activate task manager entry 8" = [ ]; # clear default
        "plasmashell"."activate task manager entry 9" = [ ]; # clear default
        "plasmashell"."clear-history" = [ ];
        "plasmashell"."clipboard_action" = "Meta+Ctrl+X";
        "plasmashell"."cycle-panels" = "Meta+Alt+P";
        "plasmashell"."cycleNextAction" = [ ];
        "plasmashell"."cyclePrevAction" = [ ];
        "plasmashell"."edit_clipboard" = [ ];
        "plasmashell"."manage activities" = "Meta+Q";
        "plasmashell"."next activity" = "Meta+Tab";
        "plasmashell"."previous activity" = "Meta+Shift+Tab";
        "plasmashell"."repeat_action" = "Meta+Ctrl+R";
        "plasmashell"."show dashboard" = "Ctrl+F12";
        "plasmashell"."show-barcode" = [ ];
        "plasmashell"."show-on-mouse-pos" = "Meta+V";
        "plasmashell"."stop current activity" = "Meta+S";
        "plasmashell"."switch to next activity" = [ ];
        "plasmashell"."switch to previous activity" = [ ];
        "plasmashell"."toggle do not disturb" = [ ];
        "systemsettings.desktop"."_launch" = "Tools";
        "systemsettings.desktop"."kcm-kscreen" = [ ];
        "systemsettings.desktop"."kcm-lookandfeel" = [ ];
        "systemsettings.desktop"."kcm-users" = [ ];
        "systemsettings.desktop"."powerdevilprofilesconfig" = [ ];
        "systemsettings.desktop"."screenlocker" = [ ];
      };
      fonts.fixedWidth = {
        family = "Hack Nerd Font";
        pointSize = 10;
        weight = 50;
      };
      configFile = {
        baloofilerc.General = let
          cfg = config.services.baloo;
        in {
          "index hidden folders" = cfg.indexHiddenFolders;
          "exclude folders" = lib.mkIf (cfg.excludeFolders != null) {
            value = arrayValue cfg.excludeFolders;
            shellExpand = true;
          };
        };
        "dolphinrc"."DetailsMode"."PreviewSize" = 16;
        "kdeglobals"."KDE"."SingleClick" = false;
        "kdeglobals"."General"."AllowKDEAppsToRememberWindowPositions" = true;
        kdeglobals.General.XftHintStyle = "hintslight";
        kdeglobals.General.XftSubPixel = lib.mkIf config.isz.plasma.subpixelHinting "rgb";
        "systemsettingsrc"."systemsettings_sidebar_mode"."HighlightNonDefaultSettings" = true;
      };
    };
  };
}
