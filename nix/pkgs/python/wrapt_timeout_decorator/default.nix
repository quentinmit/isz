{ buildPythonPackage
, fetchPypi
, setuptools
, setuptools-scm
, cli_exit_tools
, dill
, lib_detect_testenv
, multiprocess
, psutil
, wrapt
}:

let
  pname = "wrapt_timeout_decorator";
  version = "1.5.1";
in buildPythonPackage {
  inherit pname version;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-APFWRtuJximqGxVm9MHPAK5toL7s4pBQOfHNemBQamc=";
  };

  format = "pyproject";

  build-system = [
    setuptools
    setuptools-scm
  ];

  dependencies = [
    cli_exit_tools
    dill
    lib_detect_testenv
    multiprocess
    psutil
    wrapt
  ];
}
