{
  lib,
  fetchFromGitHub,
  buildHomeAssistantComponent,
  runCommand,
  beautifulsoup4,
  cloudscraper,
}:
let
  owner = "greghesp";
  version = "2.1.10";
  src = fetchFromGitHub {
    inherit owner;
    repo = "ha-bambulab";
    tag = "v${version}";
    hash = "sha256-y6HFga1GjKOP5/E44aT0QnylqdeBqnfaoWcMwtUI8Jw=";
  };
in buildHomeAssistantComponent {
  inherit owner version;
  domain = "bambu_lab";

  inherit src;

  dependencies = [
    beautifulsoup4
    cloudscraper
  ];

  passthru.cards = runCommand "ha-bambulab-cards" {
    pname = "ha-bambulab-cards";
    inherit version;
  } ''
    mkdir $out
    cp ${src}/custom_components/bambu_lab/frontend/ha-bambulab-cards.js $out/
  '';

  meta = with lib; {
    changelog = "https://github.com/greghesp/ha-bambulab/releases/tag/v${version}";
    description = "A Home Assistant Integration for Bambu Lab Printers";
    homepage = "https://github.com/greghesp/ha-bambulab";
    maintainers = with maintainers; [ quentin ];
  };
}
