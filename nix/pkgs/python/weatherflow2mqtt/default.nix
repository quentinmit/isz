{ lib
, python3Packages
, fetchFromGitHub
}:
with python3Packages;
buildPythonApplication rec {
  pname = "weatherflow2mqtt";
  version = "3.2.1";

  src = fetchFromGitHub {
    owner = "quentinmit";
    repo = "hass-weatherflow2mqtt";
    rev = "main";
    sha256 = "sha256-c5sXQmeh4TTDMCz7bihN9NHxobgR7f7UY58Q0XT9zJ0=";
  };

  pythonRelaxDeps = true;

  nativeBuildInputs = [
    flake8
    pycodestyle
    pydocstyle
    pylint
    pytest
    pytest-cov
    pytest-timeout
  ];

  propagatedBuildInputs = [
    paho-mqtt
    aiohttp
    pyyaml
    pytz
    pyweatherflowudp
  ];
}
