{ buildPythonPackage
, fetchPypi
, numba
}:

buildPythonPackage rec {
  pname = "PsychroLib";
  version = "2.5.0";

  src = fetchPypi {
    inherit pname version;
    extension = "zip";
    hash = "sha256-uTpgn/aRVjsAh5OSUrNMJFgK8xCk/xQFM7VTK4DV//8=";
  };

  propagatedBuildInputs = [
    numba
  ];
}
