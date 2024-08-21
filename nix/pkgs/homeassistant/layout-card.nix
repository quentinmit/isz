{ stdenv
, lib
, fetchurl
}:

let
  pname = "layout-card";
  version = "2.4.5";
in
stdenv.mkDerivation {
  inherit pname version;

  src = fetchurl {
    url = "https://github.com/thomasloven/lovelace-layout-card/raw/v${version}/${pname}.js";
    hash = "sha256-tV2jWyafyEwHqFiIrcUK4W+0mVz5Cq72rASpobVE054=";
  };

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    mkdir $out
    cp -v $src $out/${pname}.js
  '';

  meta = with lib; {
    description = "Get more control over the placement of lovelace cards.";
    homepage = "https://github.com/thomasloven/lovelace-layout-card";
    maintainers = with maintainers; [ quentin ];
    license = licenses.mit;
  };
}
