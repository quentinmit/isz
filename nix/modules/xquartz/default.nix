{ lib, pkgs, nixpkgs, config, options, ... }:

{
  options = with lib; {
    services.xserver = {
      enable = mkEnableOption "Xquartz";
    };
   };
  config = let
    cfg = config.services.xserver;
    fontsConf = pkgs.makeFontsConf {
      fontDirectories = config.fonts.fonts ++ [
        "/Library/Fonts"
        "~/Library/Fonts"
      ];
    };
    xquartz = pkgs.callPackage ./pkg.nix {
      inherit nixpkgs;
      inherit (pkgs.unstable) xorg;
    };
  in lib.mkIf cfg.enable {
    fonts.fonts = with pkgs; [
      xorg.fontbhlucidatypewriter100dpi
      xorg.fontbhlucidatypewriter75dpi
      ttf_bitstream_vera
      freefont_ttf
      liberation_ttf
      xorg.fontbh100dpi
      xorg.fontmiscmisc
      xorg.fontcursormisc
    ];
    environment.systemPackages = with pkgs; with xorg; [
      # non-xorg
      quartz-wm xterm fontconfig
      # xorg
      xlsfonts xfontsel
      bdftopcf fontutil iceauth libXpm lndir luit makedepend mkfontdir
      mkfontscale sessreg setxkbmap smproxy twm x11perf xauth xbacklight xclock
      xcmsdb xcursorgen xdm xdpyinfo xdriinfo xev xeyes xfs xgamma xhost
      xinput xkbcomp xkbevd xkbutils xkill xlsatoms xlsclients xmessage xmodmap
      xpr xprop xrandr xrdb xrefresh xset xsetroot xvinfo xwd xwininfo xwud
    ];
    environment.etc."X11/xinit/xinitrc".source = "${xquartz}/etc/X11/xinit/xinitrc";
    environment.etc."X11/fonts.conf".source = fontsConf;
    launchd.agents."org.nixos.xquartz.startx".serviceConfig = {
      ProgramArguments = [
        "${xquartz}/libexec/launchd_startx"
        "${xquartz}/bin/startx"
        "--"
        "${xquartz}/bin/Xquartz"
      ];
      Sockets = {
        "org.nixos.xquartz:0" = {
          SecureSocketWithKey = "DISPLAY";
        };
      };
      ServiceIPC = true;
      EnableTransactions = true;
    };
    launchd.daemons."org.nixos.xquartz.privileged_startx".serviceConfig = {
      ProgramArguments = [
        "${xquartz}/libexec/privileged_startx"
        "-d"
        "${xquartz}/etc/X11/xinit/privileged_startx.d"
      ];
      MachServices = {
        "org.nixos.xquartz.privileged_startx" = true;
      };
      TimeOut = 120;
      EnableTransactions = true;
    };
  };
}
