{ buildPythonPackage
, fetchPypi
, setuptools
}:

let
  pname = "kiutils";
  version = "1.4.8";
in buildPythonPackage {
  inherit pname version;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-GMWAMoPlec/odylV53AlSNcTng/GMNqlee1rK3Z9uEY=";
  };

  format = "pyproject";

  build-system = [
    setuptools
  ];
}
