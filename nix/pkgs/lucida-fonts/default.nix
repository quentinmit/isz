{ stdenvNoCC
, fetchFromGitHub
}:
stdenvNoCC.mkDerivation {
  name = "lucida-fonts";
  src = fetchFromGitHub {
    owner = "witt-bit";
    repo = "lucida-fonts";
    rev = "cf6fcb73284268b10999def6fe8402363577fe83";
    hash = "sha256-E6auR6luD9qSOoisGU3TaQAB2yHX5lk5tnOe1XNvZDo=";
  };
  installPhase = ''
    mkdir -p $out/share/fonts
    cp *.ttf $out/share/fonts/
  '';
}
