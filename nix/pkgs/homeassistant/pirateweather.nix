{
  lib,
  fetchFromGitHub,
  buildHomeAssistantComponent,
  colorlog,
  ruff,
}:
let
  owner = "Pirate-Weather";
  version = "1.7.7";
in buildHomeAssistantComponent {
  inherit owner version;
  domain = "pirateweather";

  src = fetchFromGitHub {
    inherit owner;
    repo = "pirate-weather-ha";
    tag = "v${version}";
    hash = "sha256-okP2mtYB1IZqzG4sJR1nDu/H0XlkVd52iasrdrcAYWU=";
  };

  dependencies = [
    colorlog
    ruff
  ];

  meta = with lib; {
    description = "Replacement for the default Dark Sky Home Assistant integration using Pirate Weather";
    license = licenses.asl20;
    homepage = "https://github.com/Pirate-Weather/pirate-weather-ha";
    maintainers = with maintainers; [ quentin ];
  };
}
