{ lib, ... }:
{
  services.home-assistant.config."scene manual" = let
    setLight = brightness: {
      brightness = lib.mkIf (brightness > 0) brightness;
      state = if (brightness > 0) then "on" else "off";
    };
    setLights = lib.mapAttrs' (
      name: brightness:
      lib.nameValuePair
        "light.${name}"
        (setLight brightness)
    );
  in [
    {
      id = "1642699417464";
      name = "Day";
      entities = setLights {
        headboard = 255;
        underlight_l = 255;
        underlight_c = 255;
      };
    }
    {
      id = "1642699468234";
      name = "Night";
      entities = setLights {
        headboard = 20;
        underlight_l = 0;
        underlight_c = 0;
      };
    }
    {
      id = "1644127210350";
      name = "Evening";
      entities = setLights {
        headboard = 51;
        underlight_l = 128;
        underlight_c = 128;
      };
    }
  ];
}