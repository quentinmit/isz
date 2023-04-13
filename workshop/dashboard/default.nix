{ lib
, python3Packages
, xorg
, material-design-icons
}:
with python3Packages;
buildPythonApplication rec {
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
    "$(find $bitmapFonts -name fonts.dir -exec dirname {} \\; | sed -z -e 's/\\n/:/g' -e 's/:$//')"
    "--set"
    "MATERIAL_ICON_FONT"
    "${material-design-icons}/share/fonts/truetype/materialdesignicons-webfont.ttf"
  ];

  src = ./.;
}
