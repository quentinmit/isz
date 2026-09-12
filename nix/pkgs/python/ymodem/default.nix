{ buildPythonPackage
, fetchPypi
, setuptools
, setuptools-scm
, ordered-set
, pyserial
}:

let
  pname = "ymodem";
  version = "1.5.3";
in buildPythonPackage {
  inherit pname version;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-LlNijZ9Tirysk7yf+3KRnfdGewJmRvdV2M8FxdVSKJ0=";
  };

  format = "pyproject";

  build-system = [
    setuptools
    setuptools-scm
  ];

  dependencies = [
    ordered-set
    pyserial
  ];
}
