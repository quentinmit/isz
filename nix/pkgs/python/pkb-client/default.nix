{ lib
, requests
, dnspython
, setuptools
, buildPythonApplication
, fetchFromGitHub
}:
let
  pname = "pkb-client";
  version = "2.3.1";
in buildPythonApplication {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "infinityofspace";
    repo = "pkb_client";
    rev = "v${version}";
    hash = "sha256-d52yzpg3Uq0GY+dzkN1aDdtf3gTuXHiNnRApI8qt0ys=";
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
