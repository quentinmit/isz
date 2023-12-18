{ lib, pkgs, config, channels, nur-mweinelt, ... }:
let
  grid = options: cards: (options // {
    type = "grid";
    inherit cards;
  });
  button = name: {
    type = "button";
    tap_action.action = "toggle";
    show_name = false;
    entity = "button.${name}";
  };
  switch_button = name: {
    type = "button";
    entity = "switch.${name}";
    show_state = true;
  };
  light = name: {
    type = "light";
    entity = "light.${name}";
  };
  climate = name: {
    type = "thermostat";
    entity = "climate.${name}";
  };
in {
  config = {
    services.home-assistant = {
      extraLovelaceModules = with nur-mweinelt.packages.${pkgs.system}.hassLovelaceModules; {
        inherit
          mushroom
          apexcharts-card
          multiple-entity-row
          slider-button-card
        ;
        inherit (pkgs.hassLovelaceModules) compass-card layout-card;
        mini-graph-card-bundle = mini-graph-card;
        # TODO: Install https://github.com/thomasloven/lovelace-card-mod, which needs to be a frontend module
        # TODO: Fix mini-graph-card to properly handle show_state: false on first line, and to show extrema from an arbitrary query.
      };
      dashboards.nix-test = {
        title = "Nix Test";
        views = [
          {
            path = "home";
            title = "Home";
            icon = "mdi:home";
            cards = [
              (grid {} [
                (switch_button "tv_power")
                (button "tv_input")
                (button "tv_enter")
              ])
              (grid {} (map button [
                "receiver_mute"
                "receiver_vol_down"
                "receiver_mute"
              ]))
              {
                type = "entities";
                entities = [ "button.hdmi_switch_2" ];
              }
              {
                type = "entities";
                entities = [ "select.receiver_source" ];
              }
              (climate "heat")
              {
                type = "custom:mushroom-light-card";
                entity = "light.living_room_floor_lamp";
                fill_container = false;
                use_light_color = true;
                show_brightness_control = true;
                show_color_temp_control = true;
                show_color_control = true;
                collapsible_controls = false;
                hold_action.action = "more-info";
                tap_action.action = "more-info";
              }
              {
                type = "sensor";
                entity = "sensor.living_room_ac_temperature";
                graph = "line";
                hours_to_show = 24;
                detail = 2;
              }
              (climate "living_room_ac")
            ];
          }
          {
            path = "tv";
            title = "TV";
            icon = "mdi:television-classic";
            cards = [
              {
                type = "entities";
                entities = map (n: "button.tv_${n}") [
                  "audio"
                  "ccd"
                  "channel_up"
                  "channel_down"
                  "last"
                  "mts"
                  "mute"
                  "vol_up"
                  "vol_down"
                ];
              }
              (grid {
                square = true;
                columns = 4;
              } ([(switch_button "tv_power")] ++ (map (n: button "tv_${n}") [
                "display"
                "playpause"
                "rewind"
                "ffw"
                "stop"
                "rep"
                "ch_list"
                "guide"
                "fav"
                "freeze"
              ])))
              (grid {
                columns = 3;
              } (map (n: button "tv_${n}") [
                "1"
                "2"
                "3"
                "4"
                "5"
                "6"
                "7"
                "8"
                "9"
                "dash"
                "0"
                "input"
              ]))
              (grid {} (map (n: button "tv_${n}") [
                "picture"
                "up"
                "temp"
                "left"
                "enter"
                "right"
                "exit"
                "down"
                "return"
                "sleep"
                "menu"
                "aspect"
              ]))
            ];
          }
          {
            title = "Receiver";
            path = "receiver";
            icon = "mdi:speaker";
            cards = [
              (grid {
                columns = 3;
              } (map (n: button "receiver_${n}") [
                "1"
                "2"
                "3"
                "4"
                "5"
                "6"
                "7"
                "8"
                "9"
                "channel_down"
                "0"
                "channel_up"
                "memory"
                "tune_down"
                "tune_up"
              ]))
              (switch_button "receiver_power")
            ];
          }
          {
            title = "Inkplate";
            path = "inkplate";
            cards = [
              {
                type = "entities";
                entities = [
                  "light.inkplate_backlight"
                  "sensor.inkplate_battery_voltage"
                  "switch.inkplate_greyscale_mode"
                  "switch.inkplate_partial_updating"
                  "button.inkplate_reboot"
                  "binary_sensor.inkplate_status"
                ];
              }
            ];
          }
        ];
      };
      lovelaceConfig = {
        title = "Ice Station Zebra";
        views = [ {
          path = "default_view";
          title = "Home";
          cards = [
            {
              type = "vertical-stack";
              cards = [
                {
                  type = "horizontal-stack";
                  cards = map light [
                    "headboard"
                    "underlight_l"
                    "underlight_c"
                  ];
                }
                {
                  type = "horizontal-stack";
                  cards = map light [
                    "living_room_floor_lamp"
                    "tree"
                    "hg02"
                  ] ++ [{
                    type = "button";
                    show_name = true;
                    show_icon = true;
                    tap_action = {
                      action = "navigate";
                      navigation_path = "/living-room";
                    };
                    icon = "mdi:sofa";
                    name = "Living Room";
                  }];
                }
                {
                  type = "entities";
                  entities = [];
                  footer.type = "buttons";
                  footer.entities = map (name: {
                    entity = "scene.${name}";
                    show_icon = true;
                    show_name = true;
                  }) [ "day" "night" "night_2" ];
                }
              ];
            }
            {
              type = "grid";
              square = false;
              columns = 2;
              cards = map climate [
                "living_room_ac"
                "bedroom_ac"
              ];
            }
          ];
        } ];
      };
    };
  };
}
