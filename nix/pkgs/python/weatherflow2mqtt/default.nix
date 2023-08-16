{ lib
, python3Packages
, fetchFromGitHub
}:
with python3Packages;
buildPythonApplication rec {
  pname = "weatherflow2mqtt";
  version = "3.1.7";

  src = fetchFromGitHub {
    owner = "quentinmit";
    repo = "hass-weatherflow2mqtt";
    rev = "main";
    sha256 = "sha256-WzY9w6NG4FF7p0NylnskANWfQdn0yvzD3FtppFEBGSg=";
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
