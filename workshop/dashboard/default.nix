{ lib
, python3Packages
, xorg
, material-design-icons
}:
with python3Packages;
let
  backendPilFontPath = "$(find $bitmapFonts -name fonts.dir -exec dirname {} \\; | sed -z -e 's/\\n/:/g' -e 's/:$//')";
  materialIconFont = "${material-design-icons}/share/fonts/truetype/materialdesignicons-webfont.ttf";
in buildPythonApplication rec {
  pname = "dashboard";
  version = "0.0.1";
  format = "pyproject";

  propagatedBuildInputs = [
    pillow
    astropy
    influxdb-client
    matplotlib
    more-itertools
    numpy
    paho-mqtt
    cherrypy
    Dozer
  ];

  bitmapFonts = [
    xorg.fontadobe100dpi
    xorg.fontadobeutopia100dpi
    xorg.fontbh100dpi
    xorg.fontbhlucidatypewriter100dpi
    xorg.fontbitstream100dpi
    xorg.fontcursormisc
    xorg.fontmiscmisc
    xorg.fontdecmisc
    xorg.fontmicromisc
    xorg.fontsonymisc
    xorg.fontsunmisc
  ];

  makeWrapperArgs = [
    "--set"
    "BACKEND_PIL_FONT_PATH"
    backendPilFontPath
    "--set"
    "MATERIAL_ICON_FONT"
    materialIconFont
  ];

  shellHook = ''
    export BACKEND_PIL_FONT_PATH=${backendPilFontPath}
    export MATERIAL_ICON_FONT=${materialIconFont}
  '';

  src = ./.;
}
