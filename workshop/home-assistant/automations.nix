{ lib, ... }:
{
  services.home-assistant.config."automation manual" = let
    cond = condition: conditions: {
      inherit condition conditions;
    };
  in [
    {
      id = "1642128421031";
      alias = "Turn off the lights when I leave home";
      trigger = [{
        platform = "state";
        entity_id = "person.quentin_smith";
        from = "home";
      }];
      action = [{
        service = "light.turn_off";
        target.area_id = [
          "bedroom"
          "workshop"
        ];
      }];
    }
    {
      id = "1642414403740";
      alias = "Turn off lights when setting alarm";
      trigger = [{
        platform = "state";
        entity_id = [
          "sensor.pixel_4a_5g_next_alarm"
          "sensor.pixel_7_pro_next_alarm"
          "sensor.pixel_8_next_alarm"
          "sensor.pixel_9_pro_xl_next_alarm"
        ];
        from = "unavailable";
      }];
      condition = [
        {
          condition = "state";
          entity_id = "person.quentin_smith";
          state = "home";
        }
        {
          condition = "time";
          after = "22:00:00";
          before = "06:00:00";
        }
        (cond "or" [
          (cond "not" [{
            condition = "state";
            entity_id = "person.jess_sheehan";
            state = "home";
          }])
          {
            condition = "state";
            entity_id = "sensor.pixel_8a_charger_type";
            state = "ac";
          }
        ])
      ];
      action = [
        {
          service = "light.turn_off";
          target.area_id = [
            "bedroom"
            "workshop"
          ];
          data.transition = 5;
        }
        {
          service = "switch.turn_off";
          target.entity_id = [
            "switch.receiver_power"
            "switch.tv_power"
          ];
        }
      ];
    }
    {
      id = "1684475136066";
      alias = "Quentin Leaving Work";
      trigger = {
        platform = "state";
        entity_id = "person.quentin_smith";
        from = "Work";
      };
      condition = [
        {
          condition = "time";
          after = "17:00:00";
        }
      ];
      action = let
        setAc = tempState: climateName: {
          "if" = [
            ({
              condition = "numeric_state";
              above = 77;
            } // tempState)
            (cond "not" [{
              condition = "state";
              entity_id = "climate.${climateName}";
              state = "cool";
            }])
          ];
          # TODO: set_fan_mode high?
          "then" = [{
            service = "climate.set_temperature";
            data.temperature = 74;
            data.hvac_mode = "cool";
            target.entity_id = "climate.${climateName}";
          }];
        };
      in [
        {
          service = "notify.mobile_app_pixel_8a";
          data = {
            message = "{{trigger.to_state.name}} has left {{trigger.from_state.state}} at {{trigger.to_state.last_changed}}";
            title = "Quentin Arrival";
            data.group = "Arrival";
            data.importance = "high";
            data.tag = "arrival-quentin";
          };
        }
        (setAc
          {
            entity_id = "climate.heat";
            attribute = "current_temperature";
          }
          "living_room_ac"
        )
        (setAc
          {
            entity_id = "sensor.bedroom_bed_temperature";
          }
          "bedroom_ac"
        )
      ];
    }
  ];
}
