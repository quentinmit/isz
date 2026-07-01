{ stdenv
, lib
, fetchurl
}:

let
  pname = "slider-button-card";
  version = "1.13.0";
in
stdenv.mkDerivation {
  inherit pname version;

  src = fetchurl {
    url = "https://github.com/custom-cards/slider-button-card/releases/download/v${version}/slider-button-card.js";
    hash = "sha256-WF4gg4Jjc78cfNkhUC21+yYYuloTJ/8qadXWI5LZngQ=";
  };

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    mkdir $out
    cp -v $src $out/slider-button-card.js
  '';

  meta = with lib; {
    description = "Lovelace Slider button card";
    homepage = "https://github.com/custom-cards/slider-button-card";
    maintainers = with maintainers; [ quentin ];
    license = licenses.mit;
  };
}
