{ lib
, buildPythonPackage
, fetchFromGitHub
, mako
, webob
, pytest
, mock
, webtest
, pillow
, setuptools
}:
let
  version = "0.9";
in buildPythonPackage {
  pname = "Dozer";
  inherit version;

  src = fetchFromGitHub {
    owner = "mgedmin";
    repo = "dozer";
    rev = version;
    sha256 = "sha256-W8XCIHs5FwDyr6MNajTdFMhcrRmgEjXX6hCb4jQE8hI=";
  };

  pyproject = true;
  build-system = [ setuptools ];

  propagatedBuildInputs = [
    mako
    webob
  ];

  checkInputs = [
    pytest
    mock
    webtest
    pillow
  ];
}
