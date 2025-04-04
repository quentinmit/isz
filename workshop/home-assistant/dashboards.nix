{ lib, pkgs, config, channels, nur-mweinelt, ... }:
let
  cond = condition: conditions: {
    inherit condition conditions;
  };
  grid = options: cards: (options // {
    type = "grid";
    inherit cards;
  });
  button = name: attrs: {
    type = "button";
    tap_action.action = "toggle";
    show_name = false;
    entity = "button.${name}";
  } // attrs;
  switch_button = name: attrs: {
    type = "button";
    entity = "switch.${name}";
    show_state = true;
  } // attrs;
  light = name: {
    type = "light";
    entity = "light.${name}";
  };
  climate = name: {
    type = "thermostat";
    entity = "climate.${name}";
  };
  power_switch = name: [
    {
      type = "conditional";
      conditions = [{
        condition = "state";
        entity = "switch.${name}";
        state_not = "unavailable";
      }];
      card = switch_button name {};
    }
    {
      type = "conditional";
      conditions = [{
        condition = "state";
        entity = "switch.${name}";
        state = "unavailable";
      }];
      card = button name { show_name = true; };
    }
  ];
in {
  config = {
    services.home-assistant = {
      customLovelaceModules = builtins.attrValues {
        inherit (pkgs.unstable.home-assistant-custom-lovelace-modules)
          mushroom
          mini-graph-card
          compass-card
          layout-card
          restriction-card
          button-card
          card-mod
          hui-element
        ;
        inherit (nur-mweinelt.packages.${pkgs.system}.hassLovelaceModules)
          apexcharts-card
          multiple-entity-row
          slider-button-card
        ;
        ha-bambulab-cards = pkgs.unstable.home-assistant-custom-components.bambu_lab.cards;
        # TODO: Install https://github.com/thomasloven/lovelace-card-mod, which needs to be a frontend module
        # TODO: Fix mini-graph-card to properly handle show_state: false on first line, and to show extrema from an arbitrary query.
      };
      dashboards.living-room = {
        title = "Living Room";
        sidebar_title = "Living Room";
        views = [
          {
            path = "home";
            title = "Home";
            icon = "mdi:home";
            cards = [
              (grid {} ((power_switch "tv_power") ++ [
                (button "tv_input" { show_name = true; })
                (button "tv_enter" { show_name = true; })
              ]))
              (grid {} [
                (button "receiver_mute" {})
                (button "receiver_vol_down" {})
                (button "receiver_vol_up" {})
              ])
              {
                type = "entities";
                entities = [
                  "button.hdmi_switch_2"
                  "select.receiver_source"
                ];
              }
              {
                type = "conditional";
                # Show the heat if the living room AC is disconnected or if the heat is turned on.
                conditions = [{
                  condition = "or";
                  conditions = [
                    {
                      condition = "state";
                      entity = "climate.living_room_ac";
                      state = "unavailable";
                    }
                    {
                      condition = "state";
                      entity = "climate.heat";
                      state_not = "off";
                    }
                  ];
                }];
                card = {
                  type = "custom:restriction-card";
                  action = "hold";
                  card = climate "heat";
                };
              }
              {
                type = "conditional";
                # Show the air conditioning if the living room AC is connected.
                conditions = [{
                    condition = "state";
                    entity = "climate.living_room_ac";
                    state_not = "unavailable";
                }];
                card = {
                  type = "custom:restriction-card";
                  action = "hold";
                  card = climate "living_room_ac";
                };
              }
              {
                type = "custom:mushroom-light-card";
                entity = "light.living_room_floor_lamp";
                fill_container = false;
                use_light_color = true;
                show_brightness_control = true;
                show_color_temp_control = true;
                show_color_control = true;
                collapsible_controls = false;
                hold_action.action = "toggle";
                tap_action.action = "more-info";
              }
              {
                type = "custom:slider-button-card";
                entity = "light.living_room_floor_lamp";
                slider = {
                  direction = "left-right";
                  background = "gradient";
                  use_state_color = true;
                  use_percentage_bg_opacity = false;
                  show_track = false;
                  toggle_on_click = false;
                  force_square = false;
                };
                show_name = true;
                show_state = true;
                compact = false;
                icon = {
                  show = true;
                  use_state_color = true;
                  tap_action.action = "more-info";
                };
                action_button = {
                  mode = "toggle";
                  icon = "mdi:power";
                  show = true;
                  show_spinner = true;
                  tap_action.action = "toggle";
                };
              }
              {
                type = "conditional";
                conditions = [{
                    condition = "state";
                    entity = "climate.living_room_ac";
                    state_not = "unavailable";
                }];
                card = {
                  type = "sensor";
                  entity = "sensor.living_room_ac_temperature";
                  graph = "line";
                  hours_to_show = 24;
                  detail = 2;
                };
              }
              {
                type = "conditional";
                conditions = [{
                    condition = "state";
                    entity = "climate.living_room_ac";
                    state_not = "unavailable";
                }];
                card = {
                  type = "entities";
                  entities = [{ entity = "sensor.living_room_ac_power"; }];
                };
              }
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
              } ((power_switch "tv_power") ++ (map (n: button "tv_${n}" { show_name = true; }) [
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
              } (map (n: button "tv_${n}" {}) [
                "1"
                "2"
                "3"
                "4"
                "5"
                "6"
                "7"
                "8"
                "9"
              ] ++ [
                (button "tv_dash" { icon = "mdi:minus"; })
                (button "tv_0" {})
                (button "tv_input" {})
              ]))
              (grid {} [
                (button "tv_picture" { icon = "mdi:image-edit"; })
                (button "tv_up" { icon = "mdi:arrow-up"; })
                (button "tv_temp" {})
                (button "tv_left" { icon = "mdi:arrow-left"; })
                (button "tv_enter" {})
                (button "tv_right" { icon = "mdi:arrow-right"; })
                (button "tv_exit" {})
                (button "tv_down" { icon = "mdi:arrow-down"; })
                (button "tv_return" { icon = "mdi:location-exit"; })
                (button "tv_sleep" {})
                (button "tv_menu" {})
                (button "tv_aspect" {})
              ])
            ];
          }
          {
            title = "Receiver";
            path = "receiver";
            icon = "mdi:speaker";
            cards = [
              (grid {
                columns = 3;
              } (map (n: button "receiver_${n}" {}) [
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
            ] ++ (power_switch "receiver_power");
          }
          {
            title = "Android TV";
            path = "android";
            icon = "mdi:android";
            cards = let
              abutton = command: attrs: {
                type = "button";
                show_name = false;
                tap_action.action = "perform-action";
                tap_action.perform_action = "remote.send_command";
                tap_action.target.entity_id = "remote.google_home_hd";
                tap_action.data = {
                  inherit command;
                };
              } // attrs;
              ahbutton = command: attrs: abutton command ({
                hold_action.action = "perform-action";
                hold_action.perform_action = "remote.send_command";
                hold_action.target.entity_id = "remote.google_home_hd";
                hold_action.data = {
                  inherit command;
                  hold_sec = 0.5;
                };
              } // attrs);
              a2button = command: command2: attrs: abutton command ({
                hold_action.action = "perform-action";
                hold_action.perform_action = "remote.send_command";
                hold_action.target.entity_id = "remote.google_home_hd";
                hold_action.data.command = command2;
              } // attrs);
            in [
              (grid {
                square = true;
                columns = 3;
              } [
                {
                  type = "button";
                  tap_action.action = "none";
                }
                (abutton "DPAD_UP" { icon = "mdi:arrow-up"; })
                {
                  type = "button";
                  tap_action.action = "none";
                }
                (abutton "DPAD_LEFT" { icon = "mdi:arrow-left"; })
                (ahbutton "DPAD_CENTER" { icon = "mdi:circle"; })
                (abutton "DPAD_RIGHT" { icon = "mdi:arrow-right"; })
                (ahbutton "BACK" { icon = "mdi:location-exit"; })
                (abutton "DPAD_DOWN" { icon = "mdi:arrow-down"; })
                (ahbutton "HOME" { icon = "mdi:home"; })
              ])
              (grid {
                square = false;
                columns = 3;
              } [
                (a2button "MEDIA_PREVIOUS" "MEDIA_REWIND" { icon = "mdi:skip-previous"; })
                (a2button "MEDIA_PLAY_PAUSE" "MEDIA_STOP" { icon = "mdi:play-pause"; })
                (a2button "MEDIA_NEXT" "MEDIA_FAST_FORWARD" { icon = "mdi:play-pause"; })
                (abutton "MUTE" { icon = "mdi:volume-off"; })
                (abutton "VOLUME_DOWN" { icon = "mdi:volume-medium"; })
                (abutton "VOLUME_UP" { icon = "mdi:volume-high"; })
              ])
              {
                type = "entity";
                entity = "remote.google_home_hd";
                attribute = "current_activity";
              }
              {
                type = "media-control";
                entity = "media_player.google_home_hd";
              }
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
                    "hg02"
                    "elgato_key_light_air"
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
