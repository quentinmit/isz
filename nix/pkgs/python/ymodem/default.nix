{ buildPythonPackage
, fetchPypi
, setuptools
, ordered-set
, pyserial
}:

let
  pname = "ymodem";
  version = "1.5.1";
in buildPythonPackage {
  inherit pname version;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-5Dc81sjSlilJXb/92e0Yewfyc4EjHVXToTcCUyDVzmc=";
  };

  format = "pyproject";

  build-system = [
    setuptools
  ];

  dependencies = [
    ordered-set
    pyserial
  ];
}
