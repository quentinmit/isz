{ buildHomeAssistantComponent
, lib
, croniter
, watchdog
, fetchFromGitHub
}:

let
  owner = "custom-components";
  domain = "pyscript";
  version = "1.7.0";
in
buildHomeAssistantComponent {
  inherit owner domain version;

  src = fetchFromGitHub {
    owner = "custom-components";
    repo = domain;
    rev = version;
    sha256 = "sha256-AphcRk9NDrD9pJI89eS5JIQSQ9XBZowP5ujfletCqyc=";
  };

  propagatedBuildInputs = [
    croniter
    watchdog
  ];

  meta = with lib; {
    description = "Pyscript adds rich Python scripting to HASS";
    homepage = "https://github.com/custom-components/${domain}";
    maintainers = with maintainers; [ quentin ];
    license = licenses.asl20;
  };
}
