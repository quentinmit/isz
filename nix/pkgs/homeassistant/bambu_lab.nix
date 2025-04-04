{
  lib,
  fetchFromGitHub,
  buildHomeAssistantComponent,
  beautifulsoup4,
  cloudscraper,
}:
let
  owner = "greghesp";
  version = "2.1.10";
in buildHomeAssistantComponent {
  inherit owner version;
  domain = "bambu_lab";

  src = fetchFromGitHub {
    inherit owner;
    repo = "ha-bambulab";
    tag = "v${version}";
    hash = "sha256-y6HFga1GjKOP5/E44aT0QnylqdeBqnfaoWcMwtUI8Jw=";
  };

  dependencies = [
    beautifulsoup4
    cloudscraper
  ];

  meta = with lib; {
    changelog = "https://github.com/greghesp/ha-bambulab/releases/tag/v${version}";
    description = "A Home Assistant Integration for Bambu Lab Printers";
    homepage = "https://github.com/greghesp/ha-bambulab";
    maintainers = with maintainers; [ quentin ];
  };
}
