{ buildPythonPackage
, fetchPypi
, setuptools
, requests
, pip-system-certs
, wrapt
, twine
}:

let
  pname = "inventree";
  version = "0.17.5";
in buildPythonPackage {
  inherit pname version;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-4AbvQSDS9o0mUtM0/osCA6Vt5Pl5K+6SInThDJfirpI=";
  };

  build-system = [
    setuptools
    wrapt
    twine
  ];

  dependencies = [
    pip-system-certs
    requests
  ];
}
