{ stdenvNoCC
, lib
, fetchFromGitHub
}:

stdenvNoCC.mkDerivation rec {
  name = "monaco-nerd-fonts";
  version = "3.0.0";

  src = fetchFromGitHub {
    owner = "Karmenzind";
    repo = name;
    rev = "a65e20d027a440577c63a28cac1972e796ba4568";
    sha256 = "+oqtEa6NZwcYBUxMCensDDy0kO7IE0dWkR8jacKEy08=";
  };

  installPhase = ''
    mkdir $out
    cp fonts/* $out/
  '';

  meta = with lib; {
    description = "monaco font patched with extra nerd glyphs";
    homepage = "https://github.com/Karmenzind/monaco-nerd-fonts";
  };
}
