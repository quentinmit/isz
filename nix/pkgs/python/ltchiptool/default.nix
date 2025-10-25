{
  python3,
  fetchPypi,
}: let
  pname = "ltchiptool";
  version = "4.12.2";
in python3.pkgs.buildPythonApplication {
  inherit pname version;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-9CVpUPLXLUIngxkqzn+SmeBJ8pCUtob7Lkn+BqjaAtY=";
  };

  format = "pyproject";

  build-system = with python3.pkgs; [
    poetry-core
  ];

  dependencies = with python3.pkgs; [
    bitstruct
    bk7231tools
    click
    colorama
    hexdump
    importlib-metadata
    prettytable
    requests
    semantic-version
    xmodem
    ymodem
    wxpython
    zeroconf
  ];
}
