{ stdenv
, lib
, fetchurl
}:

let
  pname = "restriction-card";
  version = "2.0.0-b1";
in
stdenv.mkDerivation {
  inherit pname version;

  src = fetchurl {
    url = "https://github.com/iantrich/${pname}/releases/download/${version}/${pname}.js";
    hash = "sha256-5orQiwI+E4+NCMT9eQFW24zk4dI3iFXpj1GmQtjIvsw=";
  };

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    mkdir $out
    cp -v $src $out/${pname}.js
  '';

  meta = with lib; {
    description = "Apply restrictions to Lovelace cards";
    homepage = "https://github.com/iantrich/restriction-card";
    maintainers = with maintainers; [ quentin ];
    license = licenses.mit;
  };
}
