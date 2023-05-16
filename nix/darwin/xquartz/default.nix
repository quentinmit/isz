{ lib, pkgs, nixpkgs, config, options, ... }:

{
  options = with lib; {
    services.xserver = {
      enable = mkEnableOption "Xquartz";
    };
   };
  config = let
    cfg = config.services.xserver;
    xquartz = pkgs.unstable.xquartz.override {
      unfreeFonts = true;
      extraFontDirs = config.fonts.fonts;
    };
  in lib.mkIf cfg.enable {
    fonts.fonts = with pkgs; [
      xorg.fontadobe100dpi
      xorg.fontadobe75dpi
      xorg.fontbhlucidatypewriter100dpi
      xorg.fontbhlucidatypewriter75dpi
      ttf_bitstream_vera
      freefont_ttf
      liberation_ttf
      xorg.fontbh100dpi
      xorg.fontmiscmisc
      xorg.fontcursormisc
    ];
    environment.systemPackages = [
      xquartz
    ] ++ xquartz.pkgs;
    launchd.agents."xquartz.startx".serviceConfig = {
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
    launchd.daemons."xquartz.privileged_startx".serviceConfig = {
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
