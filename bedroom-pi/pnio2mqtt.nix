{ config, lib, ... }:

{
  config = {
    isz.pnio2mqtt.enable = true;
    isz.pnio2mqtt.extraSettings = {
      ifname = "vlan981";

      name_of_station = "bedroom-caparoc";

      mqtt.server = "mqtt.isz.wtf";
      mqtt.topic_prefix = "bedroom/power";
      mqtt.device.name = "Bedroom Caparoc";

      # Update speed = 32000 Hz / 32 / 64, or ~16 Hz
      send_clock_factor = 32;
      reduction_ratio = 64;

      # This Caparoc has IOPS "BAD" despite reporting good data.
      ignore_iops = true;

      caparoc = {
        publish_interval = 1;
        channels = [
          "Router"
          "Ethernet switch"
          "bedroom-pi.isz.wtf"
          "WeatherFlow"
          "Lights"
          "Q phone charger"
          "J phone charger"
          null
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
            "Channel 1 nominal current" = "2 A";
            "Channel 2 nominal current" = "2 A";
            "Channel 3 nominal current" = "1 A";
            "Channel 4 nominal current" = "1 A";
          };
        };
        "2" = {
          id = "IDM_CAPAROC_E4_12_24DC_1_10A";
          parameters = {
            "Channel 1 nominal current" = "3 A";
            "Channel 2 nominal current" = "2 A";
            "Channel 3 nominal current" = "2 A";
            "Channel 4 nominal current" = "1 A";
          };
        };
      };
    };
  };
}
