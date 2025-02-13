{ config, lib, ... }:

{
  config = {
    isz.pnio2mqtt.enable = true;
    isz.pnio2mqtt.extraSettings = {
      ifname = "vlan981";

      name_of_station = "workshop-caparoc";

      mqtt.server = "mqtt.isz.wtf";
      mqtt.topic_prefix = "workshop/power";
      mqtt.device.name = "Workshop Caparoc";

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
          null
          "Top shelf chargers"
          "Middle shelf USB chargers"
          "Camera chargers"
          "Turnigy charger"
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
            "Channel 4 nominal current" = "1 A";
          };
        };
        "3" = {
          id = "IDM_CAPAROC_E4_12_24DC_1_10A";
          parameters = {
            "Channel 1 nominal current" = "3 A";
            "Channel 2 nominal current" = "5 A";
            "Channel 3 nominal current" = "6 A";
            "Channel 4 nominal current" = "7 A";
          };
        };
      };
    };
  };
}
