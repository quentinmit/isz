{ lib
, python3Packages
, font-adobe-100dpi
, font-adobe-utopia-100dpi
, font-bh-100dpi
, font-bh-lucidatypewriter-100dpi
, font-bitstream-100dpi
, font-cursor-misc
, font-misc-misc
, font-dec-misc
, font-micro-misc
, font-sony-misc
, font-sun-misc
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

  build-system = [
    setuptools
  ];

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
    font-adobe-100dpi
    font-adobe-utopia-100dpi
    font-bh-100dpi
    font-bh-lucidatypewriter-100dpi
    font-bitstream-100dpi
    font-cursor-misc
    font-misc-misc
    font-dec-misc
    font-micro-misc
    font-sony-misc
    font-sun-misc
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
