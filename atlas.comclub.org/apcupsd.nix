{ config, pkgs, ... }:
{
  services.apcupsd = {
    enable = true;
    configText = ''
      UPSCABLE usb
      UPSTYPE usb
      # DEVICE
      LOCKFILE /var/lock
      NOLOGINDIR /etc
      ONBATTERYDELAY 10
      BATTERYLEVEL 5
      MINUTES 3
      TIMEOUT 0
      NOLOGON disable
      KILLDELAY 0
      NETSERVER on
      NISIP 0.0.0.0
      NISPORT 3551
      EVENTSFILE /var/log/apcupsd.events
      EVENTSFILEMAX 10
      UPSCLASS standalone
      UPSMODE disable
      STATTIME 0
      STATFILE /var/log/apcupsd.status
      LOGSTATS off
      DATATIME 0
    '';
  };
}
