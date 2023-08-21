{ lib
, aiohttp
, aiohttp-socks
, jupyter-client
, jupyter-core
, buildPythonPackage
, fetchFromGitHub
}:
buildPythonPackage rec {
  pname = "hass-pyscript-kernel";
  version = "1.0.0";
  src = fetchFromGitHub {
    owner = "craigbarratt";
    repo = "hass-pyscript-jupyter";
    rev = version;
    hash = "sha256-XheDHfG6BM79JHE3VtX/z0XsvN8iDNks2Iu3PxNvS9E=";
  };

  propagatedBuildInputs = [
    aiohttp
    aiohttp-socks
    jupyter-client
    jupyter-core
  ];
}
