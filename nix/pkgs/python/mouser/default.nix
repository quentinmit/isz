{ buildPythonPackage
, fetchPypi
, requests
, click
, poetry-core
}:

let
  pname = "mouser";
  version = "0.1.6";
in buildPythonPackage {
  inherit pname version;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-Fkxv9hRfUZ/GCWNySiPo+xB0EyK4k0oP6nLS4loRkyg=";
  };

  format = "pyproject";

  build-system = [
    poetry-core
  ];

  dependencies = [
    requests
    click
  ];
}
