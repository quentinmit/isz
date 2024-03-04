{ stdenv
, rtl-sdr
, ncurses
, boost
, fetchFromGitHub
, lib
}: let
  pname = "retrogram-rtlsdr";
in stdenv.mkDerivation {
  inherit pname;
  version = "0.0.1";

  src = fetchFromGitHub {
    owner = "r4d10n";
    repo = pname;
    rev = "931cb5d5b2c01f019eb5e78b70f8058299dde698";
    hash = "sha256-uE2fFjgV7QD7MM3DtD6hKzOKbj3RGPwU6wTsj3gtS7I=";
  };

  buildInputs = [
    rtl-sdr
    ncurses
    boost
  ];

  makeFlags = [
    "CXX=c++"
  ];

  installPhase = ''
    mkdir -p $out/bin
    cp retrogram-rtlsdr $out/bin/
  '';

  meta = with lib; {
    description = "Spectrum analyzer on your terminal/ssh console with ASCII art ~ RTLSDR";
    license = licenses.gpl3;
    maintainer = with maintainers; [ quentin ];
  };
}
