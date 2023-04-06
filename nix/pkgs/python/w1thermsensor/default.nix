{ lib
, buildPythonPackage
, fetchPypi
, pkgs
, setuptools-scm
, aiofiles
, click
}:
buildPythonPackage rec {
  pname = "w1thermsensor";
  version = "2.0.0";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-EcaEr4B8icbwZu2Ty3z8AAgglf74iZ5BLpLnSOZC2cE=";
  };

  doCheck = false;

  nativeBuildInputs = [ setuptools-scm ];
  propagatedBuildInputs = [ aiofiles click ];
}
