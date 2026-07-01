{ stdenv
, lib
, fetchurl
}:

let
  pname = "slider-button-card";
  version = "1.11.0-beta";
in
stdenv.mkDerivation {
  inherit pname version;

  src = fetchurl {
    url = "https://github.com/mattieha/slider-button-card/releases/download/v${version}/slider-button-card.js";
    hash = "sha256-2Q+DLZbqgz7il00E3im4uOt0W4FYcQ1TMCfxyQgL7o4=";
  };

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    mkdir $out
    cp -v $src $out/slider-button-card.js
  '';

  meta = with lib; {
    description = "Lovelace Slider button card";
    homepage = "https://github.com/mattieha/slider-button-card";
    maintainers = with maintainers; [ hexa ];
    license = licenses.mit;
  };
}
