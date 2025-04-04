{ stdenv
, lib
, fetchFromGitHub
}:

let
  pname = "hui-element";
  version = "1.1.2";
in
stdenv.mkDerivation {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "thomasloven";
    repo = "lovelace-hui-element";
    rev = "1a805470152c86d9351abc7b0b56ef3ecb7e3a39";
    hash = "sha256-9/xdja3bkFOVbVvlQrtAl8kzPZ0jSMh2ur++k1NMqQY=";
  };

  dontBuild = true;

  installPhase = ''
    mkdir $out
    cp -v hui-element.js $out/${pname}.js
  '';

  meta = with lib; {
    description = "🔹 Use built-in elements in the wrong place";
    homepage = "https://github.com/thomasloven/lovelace-hui-element";
    maintainers = with maintainers; [ quentin ];
    license = licenses.mit;
  };
}
