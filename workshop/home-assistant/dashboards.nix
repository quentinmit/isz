{ lib, pkgs, config, channels, nur-mweinelt, ... }:
{
  config = {
    services.home-assistant = {
      extraLovelaceModules = {
        inherit (nur-mweinelt.packages.${pkgs.system}.hassLovelaceModules)
          mushroom
          apexcharts-card
          multiple-entity-row
          slider-button-card
        ;
      };
      lovelaceConfig = let
        light = (name: {
          type = "light";
          entity = "light.${name}";
        });
      in {
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
                  ];
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
          ];
        } ];
      };
    };
  };
}
