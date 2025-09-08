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
  version = "2.2.0";
  src = fetchFromGitHub {
    inherit owner;
    repo = "ha-bambulab";
    tag = "v${version}";
    hash = "sha256-R6W7v/+cAdJc3QaeKIfAdE1Xu9INpf8Y0n966bfwIVQ=";
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
