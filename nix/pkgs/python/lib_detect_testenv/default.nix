{ buildPythonPackage
, fetchPypi
, setuptools
, setuptools-scm
}:

let
  pname = "lib_detect_testenv";
  version = "2.0.8";
in buildPythonPackage {
  inherit pname version;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-llJ7MRRyfnDoD2ccIEoiWuaqrxF5g/j6T1blQrI2jUM=";
  };

  format = "pyproject";

  build-system = [
    setuptools
    setuptools-scm
  ];
}
