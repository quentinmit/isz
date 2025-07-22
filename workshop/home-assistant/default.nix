{ lib, pkgs, config, channels, ... }:
let
  dashboardFormat = pkgs.formats.yaml {};
in {
  disabledModules = [
    "services/home-automation/home-assistant.nix"
  ];
  imports = [
    "${channels.unstable}/nixos/modules/services/home-automation/home-assistant.nix"
    ./dashboards.nix
    ./scenes.nix
    ./automations.nix
  ];
  options = with lib; {
    services.home-assistant = {
      dashboards = mkOption {
        type = types.attrsOf (types.submodule ({ name, config, ... }: {
          options = {
            sidebar_title = mkOption {
              type = types.str;
              default = name;
            };
            icon = mkOption {
              type = with types; nullOr str;
              default = null;
            };
            show_in_sidebar = mkOption {
              type = types.bool;
              default = true;
            };
            require_admin = mkOption {
              type = types.bool;
              default = false;
            };
            title = mkOption {
              type = with types; nullOr str;
              default = null;
            };
            views = mkOption {
              type = types.listOf dashboardFormat.type;
              default = [];
            };
          };
        }));
        default = {};
      };
    };
  };
  config = let
    user = config.systemd.services.home-assistant.serviceConfig.User;
    group = config.systemd.services.home-assistant.serviceConfig.Group;
    dbName = "hass"; # TODO: Why does `user` cause infinite recursion?
    dbUser = user;
    dbEnabled = config.services.postgresql.enable;
  in {
    nixpkgs.overlays = [
      (self: super: {
        inherit (pkgs.unstable.extend (final: prev: {
          home-assistant = prev.home-assistant.overrideAttrs (old: {
            patches = (old.patches or []) ++ [
              ./patches/hass-mikrotik-comment.patch
              ./patches/esphome-entity-ids.patch
            ];
          });
        })) home-assistant;
      })
    ];
    nixpkgs.config.permittedInsecurePackages = [
      "openssl-1.1.1w"
    ];
    services.postgresql = {
      ensureDatabases = [dbName];
      ensureUsers = [{
        name = dbUser;
        ensureDBOwnership = true;
      }];
    };
    systemd.services.home-assistant = lib.mkIf dbEnabled {
      after = [
        "postgresql.service"
      ];
      requires = [
        "postgresql.service"
      ];
    };
    sops.secrets."home-assistant/secrets.yaml" = {
      owner = user;
      path = "${config.services.home-assistant.configDir}/secrets.yaml";
      restartUnits = [ "home-assistant.service" ];
    };
    sops.secrets."home-assistant/service-account.json" = {
      owner = user;
      path = "${config.services.home-assistant.configDir}/service-account.json";
      restartUnits = [ "home-assistant.service" ];
    };
    services.home-assistant = {
      enable = true;
      customComponents = with pkgs.unstable.home-assistant-custom-components; [
        pyscript
        bambu_lab
      ];
      extraPackages = lib.mkMerge [
        (lib.mkIf dbEnabled (python3Packages: with python3Packages; [
          # postgresql support in recorder
          psycopg2
        ]))
        (python3Packages: with python3Packages; [
          # pyscript
          croniter
          watchdog
        ])
      ];
      extraComponents = [
        "accuweather"
        "androidtv"
        "androidtv_remote"
        "apple_tv"
        "backup"
        "cast"
        "default_config"
        "device_automation"
        "elgato"
        "ffmpeg"
        "frontend"
        "http"
        "esphome"
        "google_assistant"
        "lovelace"
        "met"
        "mikrotik"
        "mobile_app"
        "moon"
        "mqtt"
        "person"
        "sun"
        "tasmota"
        "upnp"
        "websocket_api"
        "wled"
        "zone"
        "zwave_js"
        # Bluetooth dynamically loads integrations for every device that is seen.
        "bluetooth"
        "ibeacon"
        "govee_ble"
        "yalexs_ble"
        "kegtron"
        "led_ble"
        "switchbot"
        "bluemaestro"
        "oralb"
      ];
      config = let
        cleanName = name: lib.strings.toLower (lib.strings.replaceStrings [" "] ["_"] name);
      in {
        default_config = {};
        homeassistant = {
          name = "Ice Station Zebra";
          latitude = 42.36878992741952;
          longitude = -71.09414972830565;
          elevation = 3;
          unit_system = "us_customary";
          currency = "USD";
          country = "US";
          time_zone = "America/New_York";
          external_url = "https://homeassistant.isz.wtf";
        };
        http = {
          trusted_proxies = [ "::1" "127.0.0.1" ];
          use_x_forwarded_for = true;
        };
        lovelace = {
          dashboards = lib.mapAttrs (name: content: {
            mode = "yaml";
            title = content.sidebar_title;
            inherit (content) icon show_in_sidebar require_admin;
            filename = dashboardFormat.generate "${name}.yaml" {
              inherit (content) title views;
            };
          }) config.services.home-assistant.dashboards;
        };
        pyscript = {
          allow_all_imports = true;
          hass_is_global = true;
        };
        logbook = {
          exclude.entities = [
            # Don't show frequently-changing text.
            "sensor.tempest_st_00122016_wind_direction"
            "sensor.tempest_st_00122016_wind_direction_avg"
            "sensor.tempest_st_00122016_zambretti_text"
            "sensor.tempest_st_00122016_current_conditions"
            "sensor.tv_power_strip_last_seen"
            "sensor.heat_last_seen"
          ];
        };
        recorder = {
          auto_purge = false;
          exclude.entities = [
            # Don't show frequently-changing text.
            "sensor.tempest_st_00122016_wind_direction"
            "sensor.tempest_st_00122016_wind_direction_avg"
            "sensor.tempest_st_00122016_zambretti_text"
            "sensor.tempest_st_00122016_current_conditions"
            "sensor.tv_power_strip_last_seen"
            "sensor.heat_last_seen"
            # Rapid updates too frequently.
            # We'll still record the _avg versions that update every minute.
            "sensor.tempest_st_00122016_wind_speed"
            "sensor.tempest_st_00122016_wind_bearing"
            "sensor.tempest_st_00122016_wind_direction"
          ];
          exclude.entity_globs = [
            "sensor.workshop_caparoc_*"
          ];
          db_url = lib.mkIf dbEnabled "postgresql://@/${dbName}";
          db_retry_wait = 10; # Wait 10 seconds before retrying
        };
        google_assistant = {
          project_id = "api-project-64499786246";
          service_account = "!include service-account.json";
          report_state = true;
          exposed_domains = [
            "scene"
            "switch"
            "light"
            "climate"
          ];
          entity_config = {
            "media_player.tv" = { expose = true; };
            "media_player.receiver" = { expose = true; };
          };
        };
        influxdb = {
          api_version = 2;
          ssl = true;
          host = "influx.isz.wtf";
          port = 443;
          token = "!secret ha_influx_write_token";
          organization = "44ff94dc2f766f90";
          bucket = "home_assistant";
          tags = {
            source = "HA";
          };
          tags_attributes = [
            "friendly_name"
            "device_class"
          ];
          exclude.entity_globs = [
            "sensor.workshop_caparoc_*"
          ];
        };
        sensor = [
          {
            platform = "template";
            sensors = {
              sun_rising_text = {
                friendly_name = "Sun Rising Text";
                value_template = "{{ as_timestamp(states.sun.sun.attributes.next_rising) | timestamp_custom ('%H:%M') }}";
              };
              sun_setting_text = {
                friendly_name = "Sun Setting Text";
                value_template = "{{ as_timestamp(states.sun.sun.attributes.next_setting) | timestamp_custom ('%H:%M') }}";
              };
              accuweather_temperature_min_0d = {
                value_template = "{{ state_attr('weather.accuweather', 'forecast')[0].templow }}";
              };
              accuweather_temperature_max_0d = {
                value_template = "{{ state_attr('weather.accuweather', 'forecast')[0].temperature }}";
              };
            };
          }
          {
            platform = "influxdb";
            api_version = 2;
            ssl = true;
            host = "influx.isz.wtf";
            port = 443;
            token = "!secret ha_influx_read_token";
            organization = "44ff94dc2f766f90";
            bucket = "icestationzebra";
            queries_flux = let
              w1Temp = name: id: {
                name = "${name} Temperature";
                unique_id = "sensor.${cleanName name}_temperature";
                unit_of_measurement = "°F";
                query = ''
                  filter(fn: (r) => r._measurement == "temp" and r.chip == "w1" and r.sensor == "${id}")
                  |> map(fn: (r) => ({r with _value: r._value * 9./5. + 32.}))
                '';
                group_function = "last";
              };
              speed = name: {
                name = "${name} Speed";
                unique_id = "sensor.${cleanName name}_speed";
                unit_of_measurement = "Mbps";
                bucket = "speedtest";
                range_start = "-6h";
                query = ''
                  filter(fn: (r) => r["_measurement"] == "speedtest")
                  |> filter(fn: (r) => r.host == "comcast")
                  |> filter(fn: (r) => r["_field"] == "${cleanName name}_mbs")
                '';
                group_function = "last";
              };
            in [
              (w1Temp "Workshop" "00000284b00d")
              (w1Temp "Bedroom Bed" "00000284c7a7")
              (w1Temp "Outdoor" "0120541bbaa7")
              {
                name = "Eversource Power";
                unique_id = "sensor.eversource_power";
                unit_of_measurement = "W";
                bucket = "rtlamr";
                query = ''
                  filter(fn: (r) => r["_measurement"] == "rtlamr")
                  |> filter(fn: (r) => r["_field"] == "consumption")
                  |> filter(fn: (r) => r["endpoint_id"] == "21583380")
                  |> filter(fn: (r) => r["msg_type"] == "differential")
                  |> map(fn: (r) => ({r with _value: float(v: r._value * 10 * 12)}))
                '';
                group_function = "mean";
              }
              (speed "Download")
              (speed "Upload")
            ];
          }
        ];
        switch = [
          {
            platform = "template";
            switches = let
              power = name: let
                turnFrom = state: [
                  {
                    condition = "state";
                    entity_id = "switch.${cleanName name}_power";
                    inherit state;
                  }
                  {
                    service = "button.press";
                    target.entity_id = "button.${cleanName name}_power";
                  }
                ];
                in {
                  friendly_name = "${name} Power";
                  unique_id = "livingroom.${cleanName name}_power";
                  value_template = "{{ (states('sensor.${cleanName name}_power_electric_consumed_w') | float ) > 10 }}";
                  turn_on = turnFrom "off";
                  turn_off = turnFrom "on";
                };
            in {
              receiver_power = power "Receiver";
              tv_power = power "TV";
            };
          }
        ];
        media_player = [
          {
            platform = "universal";
            name = "TV";
            device_class = "tv";
            commands = {
              turn_on = {
                service = "switch.turn_on";
                target.entity_id = [
                  "switch.tv_power"
                  "switch.receiver_power"
                ];
              };
              turn_off = {
                service = "switch.turn_off";
                target = {
                  entity_id = [
                    "switch.tv_power"
                    "switch.receiver_power"
                  ];
                };
              };
              volume_up = {
                service = "button.press";
                target = {
                  entity_id = "button.receiver_vol_up";
                };
              };
              volume_down = {
                service = "button.press";
                target = {
                  entity_id = "button.receiver_vol_down";
                };
              };
              volume_mute = {
                service = "button.press";
                target = {
                  entity_id = "button.receiver_mute";
                };
              };
            };
            attributes.state = "switch.tv_power";
          }
          {
            platform = "universal";
            name = "Receiver";
            device_class = "receiver";
            commands = {
              turn_on = {
                service = "switch.turn_on";
                target.entity_id = "switch.receiver_power";
              };
              turn_off = {
                service = "switch.turn_off";
                target.entity_id = "switch.receiver_power";
              };
              volume_up = {
                service = "button.press";
                target = {
                  entity_id = "button.receiver_vol_up";
                };
              };
              volume_down = {
                service = "button.press";
                target = {
                  entity_id = "button.receiver_vol_down";
                };
              };
              volume_mute = {
                service = "button.press";
                target = {
                  entity_id = "button.receiver_mute";
                };
              };
              select_source = {
                service = "select.select_option";
                data.option = "{{ source }}";
                target.entity_id = "select.receiver_source";
              };
            };
            attributes = {
              state = "switch.receiver_power";
              source = "select.receiver_source";
              source_list = "select.receiver_source|options";
            };
          }
        ];
        weather = [
          {
            platform = "template";
            name = "WeatherFlow";
            unique_id = "weatherflow";
            condition_template = "{{ states('sensor.hub_hb_00122953_weather') }}";
            # condition_template: "{{ states('tempest_st_00122016_current_conditions') }}" # Local Only Option
            temperature_template = "{{ states('sensor.tempest_st_00122016_temperature') | float}}";
            temperature_unit = "°F";
            apparent_temperature_template = "{{ states('sensor.tempest_st_00122016_feels_like_temperature') | float}}";
            humidity_template = "{{ states('sensor.tempest_st_00122016_humidity')| int }}";
            pressure_template = "{{ states('sensor.tempest_st_00122016_sea_level_pressure')| float }}";
            pressure_unit = "inHg";
            wind_speed_template = "{{ states('sensor.tempest_st_00122016_wind_speed_avg') | float }}";
            wind_speed_unit = "mph";
            wind_bearing_template = "{{ states('sensor.tempest_st_00122016_wind_bearing_avg')| int }}";
            visibility_template = "{{ states('sensor.tempest_st_00122016_visibility')| float * 1.15078 }}";
            visibility_unit = "mi";
            forecast_hourly_template = "{{ state_attr('sensor.hub_hb_00122953_weather', 'hourly_forecast') }}";
          }
        ];

        tts = [
          {
            platform = "google_translate";
          }
        ];
        group = "!include groups.yaml";
        "automation ui" = "!include automations.yaml";
        script = "!include scripts.yaml";
        "scene ui" = "!include scenes.yaml";
      };
    };
  };
}
