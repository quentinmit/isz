{ buildPythonPackage
, fetchPypi
, setuptools
, setuptools-scm
, click
, lib_detect_testenv
}:

let
  pname = "cli_exit_tools";
  version = "1.2.7";
in buildPythonPackage {
  inherit pname version;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-51JCekqp2x8YNwyNwR6+9uJFzFiR7C+nnnFpvlg8JCM=";
  };

  format = "pyproject";

  build-system = [
    setuptools
    setuptools-scm
  ];

  dependencies = [
    click
    lib_detect_testenv
  ];
}
