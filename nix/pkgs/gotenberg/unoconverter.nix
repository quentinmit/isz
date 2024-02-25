{ lib
, stdenv
, fetchFromGitHub
, python3
, libreoffice
}:

stdenv.mkDerivation rec {
  pname = "unoconverter";
  version = "0.0.1";

  src = fetchFromGitHub {
    owner = "gotenberg";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-Ry+z6hwBMMIxfrWgbVJUMTNVas3jRlyUnQh++gaogsY=";
  };

  nativeBuildInputs = [
    python3.pkgs.wrapPython
  ];

  makeWrapperArgs = [
    "--set" "UNO_PATH" "${libreoffice}/lib/libreoffice"
  ];

  installPhase = ''
    mkdir -p $out/bin
    cp unoconv $out/bin/unoconverter
    chmod +x $out/bin/unoconverter
  '';

  postFixup = ''
    wrapPythonProgramsIn "$out/bin" "$out ${python3}"
  '';
}
