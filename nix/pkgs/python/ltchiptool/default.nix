{
  python3,
  fetchPypi,
  wrapGAppsHook3,
}: let
  pname = "ltchiptool";
  version = "4.14.4";
in python3.pkgs.buildPythonApplication {
  inherit pname version;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-MDGVIaAPasrUmHkorSvLew5Z9qn4cJgc1XBCZNZE250=";
  };

  format = "pyproject";

  build-system = with python3.pkgs; [
    poetry-core
  ];

  nativeBuildInputs = [
    wrapGAppsHook3
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
