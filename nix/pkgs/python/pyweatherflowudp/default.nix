{ lib
, buildPythonPackage
, fetchPypi
, pint
, psychrolib
, poetry-core
}:

buildPythonPackage rec {
  pname = "pyweatherflowudp";
  version = "1.4.2";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-Dv48o+LI16CT3dOWNWwATeSxl7skO6rdQnFGi2QHytE=";
  };

  format = "pyproject";

  #prePatch = ''
  #  substituteInPlace pyproject.toml \
  #    --replace "^0.19" ">=0.19"
  #'';
  patches = [
    ./pint.patch
  ];

  nativeBuildInputs = [
    poetry-core
  ];

  propagatedBuildInputs = [
    pint
    psychrolib
  ];
}
