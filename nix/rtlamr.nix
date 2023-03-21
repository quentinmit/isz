{ lib, pkgs, config, ... }:
with lib;
{
  options = {
    services.rtl-tcp = {
      enable = mkOption{
        default = false;
        type = with types; bool;
        description = ''
          Start an irc client for a user.
        '';
      };
      usbVid = mkOption{
        default = 0x0bda;
        type = with types; nullOr (int);
        description = ''USB VID.'';
      };
      usbPid = mkOption{
        default = 0x2838;
        type = with types; nullOr (int);
        description = ''USB PID.'';
      };
    };
  };
  config = {
    hardware.rtl-sdr.enable = true;
    environment.systemPackages = with pkgs; [
      rtl-sdr
      rtlamr
    ];
    systemd.services.rtl-tcp = mkIf config.services.rtl-tcp.enable {
      description = "RTL-SDR TCP server";
      path = [ pkgs.rtl-sdr ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = ''${pkgs.rtl-sdr}/bin/rtl_tcp -a 0.0.0.0'';
      };
    };
    # TODO: Put rule in a package and use services.udev.packages
    services.udev.extraRules = mkIf config.services.rtl-tcp.enable ''
      SUBSYSTEM=="usb", DRIVER=="usb", ATTR{idProduct}=="${config.services.rtl-tcp.usbVid}", ATTR{idVendor}=="${config.services.rtl-tcp.usbPid}", TAG+="systemd", ENV{SYSTEMD_WANTS}+="rtl-tcp"
    '';
  };
}
