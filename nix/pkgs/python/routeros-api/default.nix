{ lib
, buildPythonPackage
, fetchPypi
, pkgs
, setuptools-scm
, six
}:

buildPythonPackage rec {
  pname = "RouterOS-api";
  version = "0.17.0";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-G5iYRg7MRme1Tkd9SVt0wvJK4KrEyQ3Q5i8j7H6uglI=";
  };

  doCheck = false;

  nativeBuildInputs = [ setuptools-scm ];
  propagatedBuildInputs = [ six ];
}
