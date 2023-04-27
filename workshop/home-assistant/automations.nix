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
            entity_id = "binary_sensor.jess_pixel_4a_is_charging";
            state = "on";
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
  ];
}
