{ name
, src
, p7zip
, xar
, cpio
, stdenvNoCC
}:
stdenvNoCC.mkDerivation {
  inherit name src;
  nativeBuildInputs = [
    p7zip
    xar
    cpio
  ];
  unpackPhase = ''
    7z x $src
    xar -xf */*.pkg
    zcat *.pkg/Payload | cpio -i
  '';
  installPhase = ''
    mkdir -p $out/share/fonts
    cp Library/Fonts/* $out/share/fonts/
  '';
}
