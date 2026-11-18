{ buildHomeAssistantComponent
, lib
, croniter
, watchdog
, fetchFromGitHub
}:

let
  owner = "custom-components";
  domain = "pyscript";
  version = "2.1.1";
in
buildHomeAssistantComponent {
  inherit owner domain version;

  src = fetchFromGitHub {
    owner = "custom-components";
    repo = domain;
    rev = version;
    sha256 = "sha256-wEcoelIEfmJzQdPyB1OZ0yvvGSv347j2oJdlRvDeF1I=";
  };

  propagatedBuildInputs = [
    croniter
    watchdog
  ];

  ignoreVersionRequirement = [
    # nixpkgs has croniter 6.2.4, pyscript requires exactly 6.0.0
    "croniter"
  ];

  meta = with lib; {
    description = "Pyscript adds rich Python scripting to HASS";
    homepage = "https://github.com/custom-components/${domain}";
    maintainers = with maintainers; [ quentin ];
    license = licenses.asl20;
  };
}
