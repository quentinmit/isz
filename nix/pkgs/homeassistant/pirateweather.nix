{
  lib,
  fetchFromGitHub,
  buildHomeAssistantComponent,
  colorlog,
  ruff,
}:
let
  owner = "Pirate-Weather";
  version = "1.9.0";
in buildHomeAssistantComponent {
  inherit owner version;
  domain = "pirateweather";

  src = fetchFromGitHub {
    inherit owner;
    repo = "pirate-weather-ha";
    tag = "v${version}";
    hash = "sha256-LIlKYrKoSElZkU9To8XZrposweAYRhu2x59h1p4av44=";
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
