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
  version = "0.21.1";
in buildPythonPackage {
  inherit pname version;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-+yxuUsTIXg8BYEwd8EYiaqNelgW7yTi91jgS2I39dvs=";
  };

  pyproject = true;

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
