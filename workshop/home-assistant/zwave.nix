{ lib, pkgs, config, ... }:
{
  # Configure home-assistant for Zwave
  services.home-assistant.extraComponents = [
    "zwave_js"
  ];
  # Configure udev for Zwave
  services.udev.rules = [
    {
      SUBSYSTEM = "tty";
      "ATTRS{idProduct}" = "0200";
      "ATTRS{idVendor}" = "0658";
      RUN = { op = "+="; value = "${pkgs.coreutils}/bin/ln -f $devnode /dev/ttyZwave"; };
    }
  ];
  # Configure zwave-js-ui
  services.zwave-js-ui = {
    enable = true;
    package = pkgs.unstable.zwave-js-ui;
    serialPort = "/dev/ttyZwave";
    settings.HOME = "%t/zwave-js-ui";
    settings.BACKUPS_DIR = "%S/zwave-js-ui/backups";
    settings.TZ = config.time.timeZone;
  };
  systemd.services.zwave-js-ui = let
    deps = ["modprobe@cdc_acm.service"];
  in {
    wants = deps;
    after = deps;
    serviceConfig.BindReadOnlyPaths = [
      "/etc/resolv.conf"
    ];
    serviceConfig.RestrictAddressFamilies = lib.mkForce "AF_INET AF_INET6 AF_NETLINK";
  };

}
