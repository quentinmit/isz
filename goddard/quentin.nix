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
      ];

      services.easyeffects.enable = true;

      programs.plasma = {
        configFile = {
          kcminputrc.Libinput."2362"."628"."PIXA3854:00 093A:0274 Touchpad" = {
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
