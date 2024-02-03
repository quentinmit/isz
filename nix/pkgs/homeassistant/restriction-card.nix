{ stdenv
, lib
, fetchurl
}:

let
  pname = "restriction-card";
  version = "1.2.9";
in
stdenv.mkDerivation {
  inherit pname version;

  src = fetchurl {
    url = "https://github.com/iantrich/${pname}/releases/download/${version}/${pname}.js";
    hash = "sha256-rg2vBaYo8h+E4egMdIy5brPkvpvqSEpRkiAo5lso/Ts=";
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
