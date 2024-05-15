{ config, pkgs, lib, ... }:

{
  home-manager.users.quentin = lib.mkMerge [
    {
      home.stateVersion = "23.11";

      isz.quentin.enable = true;
      isz.graphical = true;
      isz.plasma.enable = true;

      programs.atuin.settings.sync_address = "https://atuin.isz.wtf";

      home.packages = with pkgs; [
        google-chrome
        evtest-qt
        vulkan-caps-viewer
        opensnitch-ui
        signal-desktop
        discord
        davinci-resolve-studio
        zoom-us
        caprine-bin
        jdk
        krfb
      ];

      # Don't index Electron folders
      services.baloo.excludeFolders = [
        "$HOME/.config/discord/"
        "$HOME/.config/Signal/"
      ];

      services.easyeffects = {
        enable = true;
        autoload.output.fw-16 = [{
          device = "alsa_output.pci-0000_c1_00.6.analog-stereo";
          device-description = "Family 17h/19h HD Audio Controller Analog Stereo";
          device-profile = "analog-output-speaker";
        }];
      };
      xdg.configFile."easyeffects/output/fw-16.json".source = ./easyeffects/fw-16.json;

      programs.plasma = {
        configFile = {
          kcminputrc."Libinput/2362/628/PIXA3854:00 093A:0274 Touchpad" = {
            ClickMethod = 2; # Two-finger click to right click
            TapToClick = true;
            TapDragLock = true;
          };
          kwinrc.Xwayland.Scale = 1.25;
          powermanagementprofilesrc = {
            # Absence of group indicates do not suspend
            AC.SuspendSession = null;
          };
        };
      };
    }
    # Emacs
    {
      programs.emacs = {
        enable = true;
        package = pkgs.emacs;
        extraPackages = epkgs: with epkgs; [
          nix-mode
          magit
          go-mode
          yaml-mode
        ];
      };
    }
  ];
}
