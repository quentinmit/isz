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
    sha256 = "sha256-Yf+gxj3z6IQ0fo1KD8A1pq0OeVKqy16jGALXkJpE2EA=";
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
