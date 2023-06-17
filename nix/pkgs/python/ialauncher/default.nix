{ lib
, python3Packages
, fetchPypi
, dosbox
}:
with python3Packages;
buildPythonApplication rec {
  pname = "ialauncher";
  version = "2.2.1";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-pxZKsjrzSSLsm55KpkwP0d380KGu05SgZvjDXeJAkWA=";
  };

  patches = [
    ./xdg.patch
  ];

  buildInputs = [
    dosbox
  ];
  propagatedBuildInputs = [
    pygame
    pyxdg
  ];

  dontCheck = true;
  dontUseSetuptoolsCheck = true;

  makeWrapperArgs = [
    "--set"
    "PATH"
    (lib.makeBinPath [
      dosbox
    ])
  ];
}
