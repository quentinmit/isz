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
    sha256 = "sha256-noA/1DwTdf1Sa8yLzILardmEMjcI4xupsfsQUdEuESA=";
  };

  pyproject = true;
  build-system = [ setuptools ];

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
