{ lib
, requests
, dnspython
, setuptools
, buildPythonApplication
, fetchFromGitHub
}:
let
  pname = "pkb-client";
  version = "2.3.0";
in buildPythonApplication {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "infinityofspace";
    repo = "pkb_client";
    rev = "v${version}";
    hash = "sha256-nUj6OxjAarv6kCyknkS1x8kIXF7ihs/oqygUxc0S+90=";
  };

  pyproject = true;

  build-system = [
    setuptools
  ];

  dependencies = [
    requests
    dnspython
  ];

  meta = {
    homepage = "https://infinityofspace.github.io/pkb_client/";
    license = lib.licenses.mit;
    description = "Python client for the Porkbun API";
    maintainers = [ lib.maintainers.quentin ];
    mainProgram = "pkb-client";
  };
}
