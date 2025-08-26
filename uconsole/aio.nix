{ lib, pkgs, config, nixos-meshtastic, ... }:
{
  imports = [
    nixos-meshtastic.nixosModules.default
  ];
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
      users.groups.gpio = {};
      services.udev.rules = [
        {
          SUBSYSTEM = "spidev";
          KERNEL = "spidev1.0";
          OWNER = { op = "="; value = config.services.meshtastic.user; };
        }
        {
          SUBSYSTEM = "gpio";
          GROUP = { op = "="; value = "gpio"; };
        }
      ];

      # TODO: Install meshtastic
      systemd.sockets.gpsd-nmea.socketConfig.ListenFIFO = ["/run/gpsd-meshtastic.fifo"];
      services.meshtastic = {
        enable = true;
        package = (pkgs.extend nixos-meshtastic.overlays.default).meshtasticd;
        settings = {
          Lora = {
            Module = "sx1262";  # HackerGadgets RTL-SDR/LoRa extension board
            DIO2_AS_RF_SWITCH = true;
            DIO3_TCXO_VOLTAGE = true;
            IRQ = 26;
            Busy = 24;
            Reset = 25;
            spidev = "spidev1.0";
          };
          GPS.SerialPath = "/run/gpsd-meshtastic.fifo";
          Webserver.Port = 9443;
          # General.MACAddress = "";
        };
      };
    }
  ];
}
