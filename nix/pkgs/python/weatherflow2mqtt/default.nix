{ lib
, python3Packages
, fetchFromGitHub
}:
with python3Packages;
buildPythonApplication rec {
  pname = "weatherflow2mqtt";
  version = "3.2.1";

  src = fetchFromGitHub {
    owner = "briis";
    repo = "hass-weatherflow2mqtt";
    rev = "4004687fbf257044e8922ecc3b20408bcc1d7d3f";
    sha256 = "sha256-7lnsy8vlLWK11vwVTxIkc/lg0WBIanrLi6mfiKDX3wI=";
  };

  prePatch = ''
    sed -i 's/==.*//' requirements.txt test_requirements.txt
  '';

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
