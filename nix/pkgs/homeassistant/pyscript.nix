{ buildHomeAssistantComponent
, lib
, croniter
, watchdog
, fetchFromGitHub
}:

let
  owner = "custom-components";
  domain = "pyscript";
  version = "2.0.1";
in
buildHomeAssistantComponent {
  inherit owner domain version;

  src = fetchFromGitHub {
    owner = "custom-components";
    repo = domain;
    rev = version;
    sha256 = "sha256-5jQUQit0luGAxbfGKETvqWmo8mBdFQarEuAevVZ67nM=";
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
