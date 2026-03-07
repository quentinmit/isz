{
  lib,
  fetchFromGitHub,
  buildHomeAssistantComponent,
  colorlog,
  ruff,
}:
let
  owner = "Pirate-Weather";
  version = "1.8.4";
in buildHomeAssistantComponent {
  inherit owner version;
  domain = "pirateweather";

  src = fetchFromGitHub {
    inherit owner;
    repo = "pirate-weather-ha";
    tag = "v${version}";
    hash = "sha256-rGjpjO4Jnm1SuQBiqhzb80lNonUKmX0tkAL+DhLxMnw=";
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
