{ lib
, python3Packages
, fetchFromGitHub
}:
let
  version = "1.2.0";
  digikey-api = let
    pname = "digikey-api";
    version = "master";
  in
  { buildPythonPackage
  , fetchFromGitHub
  , requests
  , retrying
  , inflection
  , certauth
  , urllib3
  , setuptools
  , distutils
  }: buildPythonPackage {
    inherit pname version;

    src = fetchFromGitHub {
      owner = "hurricaneJoef";
      repo = "digikey-api";
      rev = "e4418f4aeb1c49c1e9b6c11f07e0b14567a43099";
      hash = "sha256-xL/+uiRtJGzmHgqFZgUM8AByH6Mm3pA7RE/tS2/hnOo=";
    };

    pyproject = true;

    build-system = [
      setuptools
    ];

    dependencies = [
      requests
      retrying
      inflection
      certauth
      urllib3
      distutils
    ];
  };
in python3Packages.buildPythonApplication {
  pname = "kintree";
  inherit version;

  src = fetchFromGitHub {
    owner = "sparkmicro";
    repo = "Ki-nTree";
    rev = version;
    hash = "sha256-wWW/VLbRvnz32r+Drf3GbWflCkjCNqTZUTdxghrW5os=";
  };

  patches = [
    ./flet-1.0.patch
  ];

  build-system = with python3Packages; [
    setuptools
    poetry-core
  ];

  format = "pyproject";

  dontCheckRuntimeDeps = true;

  dependencies = with python3Packages; [
    (callPackage digikey-api {})
    flet
    flet-desktop
    thefuzz
    inventree
    kiutils
    mouser
    multiprocess
    pyyaml
    validators
    wrapt_timeout_decorator
    cloudscraper
  ];

  meta = with lib; {
    homepage = "https://github.com/sparkmicro/Ki-nTree";
    license = licenses.gpl3Plus;
    description = "Fast part creation for KiCad and InvenTree";
    maintainers = [ maintainers.quentin ];
  };
}
