{ config, pkgs, lib, ... }:

{
  home-manager.users.quentin = lib.mkMerge [
    {
      home.stateVersion = "23.11";

      isz.quentin.enable = true;
      isz.graphical = true;
      isz.plasma.enable = true;
      isz.plasma.subpixelHinting = true;

      programs.atuin.settings.sync_address = "https://atuin.isz.wtf";

      home.packages = with pkgs; [
        google-chrome
        evtest-qt
        vulkan-caps-viewer
        opensnitch-ui
        signal-desktop
        #discord
        vesktop
        davinci-resolve-studio
        zoom-us
        caprine-bin
        jdk
        kdePackages.krfb
        google-cloud-sdk
        baudline
        pkgsi686Linux.mplayer-unfree
        element-desktop
        unleashed-recomp
        hedge-mod-manager
        plasma-homeassistant
        home-assistant-cli
        zapzap
      ];

      services.baloo.excludeFolders = [
        # Don't index Electron folders
        "$HOME/.config/"
        "$HOME/.cache/"
        "$HOME/Software/nixpkgs/"
        "$HOME/.local/share/"
        "$HOME/.gradle/"
        "$HOME/.zoom/"
        "$HOME/.npm/"
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
        powerdevil.AC.autoSuspend.action = "nothing";
        configFile = {
          kcminputrc."Libinput/2362/628/PIXA3854:00 093A:0274 Touchpad" = {
            ClickMethod = 2; # Two-finger click to right click
            TapToClick = true;
            TapDragLock = true;
          };
          kwinrc.Xwayland.Scale = 1.25;
          powermanagementprofilesrc = { # KDE 5
            # Absence of group indicates do not suspend
            AC.SuspendSession = null;
          };
        };
      };

      xdg.configFile = {
        "autostart/signal-desktop.desktop".source = "${pkgs.signal-desktop}/share/applications/signal-desktop.desktop";
        "autostart/caprine.desktop".source = "${pkgs.caprine-bin}/share/applications/caprine.desktop";
        #"autostart/discord.desktop".source = "${pkgs.discord}/share/applications/discord.desktop";
        "autostart/vesktop.desktop".source = "${pkgs.vesktop}/share/applications/vesktop.desktop";
      };

      xdg.dataFile."DaVinciResolve/configs/.soundlibrary".text = "${pkgs.fairlight-sound-library}";
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
    {
      programs.git.extraConfig.url = {
        "git@github.com:mitmh2025".insteadOf = [
          "https://github.com/mitmh2025"
        ];
      };
    }
  ];
}
