{ stdenv
, lib
, fetchurl
}:

let
  pname = "compass-card";
  version = "2.0.2";
in
stdenv.mkDerivation {
  inherit pname version;

  src = fetchurl {
    url = "https://github.com/tomvanswam/${pname}/releases/download/v${version}/${pname}.js";
    hash = "sha256-WFTqLye24PU0tO4ENonMT7qe4BKOhZprLPIgTWp9Qgw=";
  };

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    mkdir $out
    cp -v $src $out/${pname}.js
  '';

  meta = with lib; {
    description = "A Lovelace card that shows a directional indicator on a compass for Home Assistant";
    homepage = "https://github.com/tomvanswam/${pname}";
    maintainers = with maintainers; [ quentin ];
    license = licenses.mit;
  };
}
