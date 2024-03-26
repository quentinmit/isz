{ lib
, fetchFromGitHub
, stdenv
}:
let
  version = "4.1.1";
in stdenv.mkDerivation {
  pname = "86box-roms";
  inherit version;
  src = fetchFromGitHub {
    owner = "86Box";
    repo = "roms";
    rev = "v${version}";
    hash = "sha256-58nNTOLund/KeDlNwzwwihjFVigs/P0K8SN07zExE2c=";
  };

  installPhase = ''
    mkdir -p $out/share/86Box/
    cp -a . $out/share/86Box/roms
  '';
}
