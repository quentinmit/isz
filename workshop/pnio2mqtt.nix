{ config, lib, ... }:

{
  config = {
    sops.secrets.profinet_influx_token = {};
    sops.secrets."greptimedb/users/pnio2mqtt@workshop.isz.wtf" = {};
    sops.templates."pnio2mqtt.env" = {
      content = ''
        INFLUX_TOKEN=${config.sops.placeholder.profinet_influx_token}
        GREPTIMEDB_TOKEN=${config.sops.placeholder."greptimedb/users/pnio2mqtt@workshop.isz.wtf"}
      '';
    };
    systemd.services.pnio2mqtt.serviceConfig.EnvironmentFile = [
      config.sops.templates."pnio2mqtt.env".path
    ];
    isz.pnio2mqtt.enable = true;
    isz.pnio2mqtt.settings = {
      ifname = "vlan981";

      name_of_station = "workshop-caparoc";

      mqtt.server = "mqtt.isz.wtf";
      mqtt.topic_prefix = "workshop/power";
      mqtt.device.name = "Workshop Caparoc";

      influxdb = [
        {
          host = "http://influx.isz.wtf:8086";
          org = "icestationzebra";
          bucket = "profinet";
          token = "$INFLUX_TOKEN";
        }
        {
          host = "https://greptimedb.isz.wtf/v1/influxdb";
          org = "";
          bucket = "profinet";
          token = "pnio2mqtt@workshop.isz.wtf:$GREPTIMEDB_TOKEN";
        }
      ];

      # Update speed = 32000 Hz / 32 / 64, or ~16 Hz
      send_clock_factor = 32;
      reduction_ratio = 64;

      caparoc = {
        publish_interval = 1;
        channels = [
          "Ethernet switch"
          "workshop.isz.wtf"
          "workshop.isz.wtf USB hubs"
          "Cable modem"

          "Front panel DC"
          "Front panel USB-C"
          "workshop-10g-sw.isz.wtf"
          "build-arm.isz.wtf"

          "Top shelf chargers"
          "Middle shelf USB chargers"
          "Camera chargers"
          "Front panel 140W USB-C"
        ];
      };

      slots = {
        "0" = {
          id = "DAP_CAPAROC_FEED_IN";
          subslots = {
            "1" = {
              id = "VID_IRT_Submodule";
            };
            "2" = {
              id = "IDS_CAPAROC_General_System_Data";
              parameters = {
                "Lock current programming for all channels" = "Disable";
                "Local user interface lock" = "Disable";
                "Switch-on delay" = "25 ms";
                "Operating mode after startup" = "Independent mode";
                Webserver = "Enable";
              };
            };
            "0x8000".id = "IDS_2";
            "0x8001".id = "IDS_2P1";
          };
        };
        "1" = {
          id = "IDM_CAPAROC_E4_12_24DC_1_10A";
          parameters = {
            "Channel 1 nominal current" = "6 A";
            "Channel 2 nominal current" = "10 A";
            "Channel 3 nominal current" = "2 A";
            "Channel 4 nominal current" = "3 A";
          };
        };
        "2" = {
          id = "IDM_CAPAROC_E4_12_24DC_1_10A";
          parameters = {
            "Channel 1 nominal current" = "5 A";
            "Channel 2 nominal current" = "7 A";
            "Channel 3 nominal current" = "3 A";
            "Channel 4 nominal current" = "4 A";
          };
        };
        "3" = {
          id = "IDM_CAPAROC_E4_12_24DC_1_10A";
          parameters = {
            "Channel 1 nominal current" = "3 A";
            "Channel 2 nominal current" = "5 A";
            "Channel 3 nominal current" = "6 A";
            "Channel 4 nominal current" = "10 A";
          };
        };
      };
    };
  };
}
