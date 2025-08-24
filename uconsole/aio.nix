{ lib, pkgs, config, ... }:
{
  config = lib.mkMerge [
    {
      # GPS
      boot.kernelParams = [
        "8250.nr_uarts=1"
        "console=tty0"
      ];

      environment.systemPackages = with pkgs; [
        gpsd
      ];

      programs.mepo = {
        enable = true;
        locationBackends.gpsd = true;
      };

      services.gpsd = {
        enable = true;
        devices = ["/dev/ttyS0"];
      };

      systemd.sockets.gpsd-nmea = {
        description = "GPSD NMEA sentences";
        wantedBy = ["sockets.target"];
        listenStreams = ["/run/gpsd-nmea.sock"];
        socketConfig.Accept = true;
        # TODO: Restrict to gpsd user?
      };
      systemd.services."gpsd-nmea@" = {
        description = "GPSD NMEA connection";
        wants = ["gpsd.service"];
        after = ["gpsd.service"];
        unitConfig.CollectMode = "inactive-or-failed";
        serviceConfig.Type = "exec";
        serviceConfig.DynamicUser = true;
        serviceConfig.ExecStart = "${lib.getExe' pkgs.gpsd "gpspipe"} -r";
        serviceConfig.StandardOutput = "socket";
      };

      services.geoclue2 = {
        enable = true;
      };
      # All this work just to set network-nmea.nmea-socket.
      environment.etc."geoclue/geoclue.conf".text = let
        cfg = config.services.geoclue2;
        defaultWhitelist = [
          "gnome-shell"
          "io.elementary.desktop.agent-geoclue2"
        ];
        appConfigToINICompatible =
          _:
          {
            desktopID,
            isAllowed,
            isSystem,
            users,
            ...
          }:
          {
            name = desktopID;
            value = {
              allowed = isAllowed;
              system = isSystem;
              users = lib.concatStringsSep ";" users;
            };
          };
      in lib.mkForce (lib.generators.toINI { } (
      {
        agent.whitelist = lib.concatStringsSep ";" (
          lib.optional cfg.enableDemoAgent "geoclue-demo-agent" ++ defaultWhitelist
        );
        network-nmea.enable = cfg.enableNmea;
        network-nmea.nmea-socket = "/run/gpsd-nmea.sock";
        "3g".enable = cfg.enable3G;
        cdma.enable = cfg.enableCDMA;
        modem-gps.enable = cfg.enableModemGPS;
        wifi = {
          enable = cfg.enableWifi;
        } // lib.optionalAttrs cfg.enableWifi {
          url = cfg.geoProviderUrl;
          submit-data = lib.boolToString cfg.submitData;
          submission-url = cfg.submissionUrl;
          submission-nick = cfg.submissionNick;
        };
        static-source.enable = cfg.enableStatic;
      } // lib.mapAttrs' appConfigToINICompatible cfg.appConfig
      ));
    }
    {
      # RTL SDR
      hardware.rtl-sdr.enable = true;
    }
    {
      # RTC
      hardware.deviceTree.overlaysParams = [
        {
          name = "bcm2711-rpi-cm4";
          params.i2c_arm = "on";
        }
        {
          name = "i2c-rtc";
          params = {
            i2c1 = "on";
            pcf85063a = "on";
          };
        }
      ];
      hardware.raspberry-pi."4".overlays = {
        cpi-i2c1.enable = true;
        i2c-rtc.enable = true;
      };
    }
    {
      # LoRa
      hardware.deviceTree.overlaysParams = [
        {
          name = "bcm2711-rpi-cm4";
          params.spi = "on";
        }
      ];
      hardware.deviceTree.overlays = [
        {
          name = "spi1-1cs";
          filter = "bcm2711-rpi-*.dtb";
          dtsFile = ./spi1-1cs-overlay.dts;
        }
      ];
      # TODO: Install meshtastic
    }
  ];
}
