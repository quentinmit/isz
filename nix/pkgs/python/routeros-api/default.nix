{ lib
, buildPythonPackage
, fetchPypi
, pkgs
, setuptools-scm
, six
}:

buildPythonPackage rec {
  pname = "routeros_api";
  version = "0.18.1";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-I6Qm+KO4D659mTEewCU7GYlO0tFoiyAoHeqEe9k8t7w=";
  };

  patches = [
    ./ros718.patch
  ];

  doCheck = false;

  nativeBuildInputs = [ setuptools-scm ];
  propagatedBuildInputs = [ six ];
}
