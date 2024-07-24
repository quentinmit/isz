{ config, lib, pkgs, ... }:
{
  options = with lib; {
    isz.pipewire.enable = mkEnableOption "Pipewire";
  };
  config = lib.mkIf config.isz.pipewire.enable {
    environment.systemPackages = with pkgs; [
      pipewire.jack
    ];

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      jack.enable = true;
      pulse.enable = true;
    };

    security.pam.loginLimits = [
      {
        domain = "@audio";
        item = "memlock";
        type = "-";
        value = "unlimited";
      }
      {
        domain = "@audio";
        item = "rtprio";
        type = "-";
        value = "95";
      }
      {
        domain = "@audio";
        item = "nice";
        type = "-";
        value = "-19";
      }
    ];
  };
}
