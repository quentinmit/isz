{ lib
, python3Packages
, fetchFromGitHub
, qt6
}:
with python3Packages;
buildPythonApplication rec {
  pname = "dwex";
  version = "4.47";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "sevaa";
    repo = pname;
    rev = version;
    hash = "sha256-kSL7ucp42f+bvFCc6cfA85CV/1xztqjgXIsBDf/OJuE=";
  };

  build-system = with python3Packages; [
    setuptools
  ];

  nativeBuildInputs = [
    qt6.wrapQtAppsHook
  ];

  dontWrapQtApps = true;

  makeWrapperArgs = [
    "\${qtWrapperArgs[@]}"
  ];

  buildInputs = [
    qt6.qtwayland
  ];

  dependencies = with python3Packages; [
    pyelftools
    filebytes
    pyqt6
  ];

  meta = with lib; {
    homepage = "https://github.com/sevaa/dwex";
    license = licenses.bsd2;
    description = "DWARF Explorer - a GUI utility for navigating the DWARF debug information";
    maintainers = [ maintainers.quentin ];
  };
}
