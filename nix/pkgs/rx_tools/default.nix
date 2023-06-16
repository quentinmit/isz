{ lib
, stdenv
, cmake
, soapysdr
, fetchFromGitHub
}:

stdenv.mkDerivation rec {
  pname = "rx_tools";
  version = "20190421";

  src = fetchFromGitHub {
    owner = "rxseger";
    repo = "rx_tools";
    rev = "811b21c4c8a592515279bd19f7460c6e4ff0551c";
    sha256 = "WacMVC0rohyHnZexGj2Zby9aD4AYwJvljACbzQDAKGM=";
  };

  nativeBuildInputs = [
    cmake
  ];

  buildInputs = [
    soapysdr
  ];
}
