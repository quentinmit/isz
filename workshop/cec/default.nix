{ lib
, python3Packages
}:
with python3Packages;
buildPythonApplication rec {
  pname = "cec";
  version = "0.0.1";
  format = "pyproject";

  propagatedBuildInputs = [
    paho-mqtt
    (pycec.override { libcec = null; })
  ];

  buildInputs = [
    setuptools
  ];

  src = ./.;
}
