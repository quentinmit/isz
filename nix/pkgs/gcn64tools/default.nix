{ lib
, stdenv
, fetchFromGitHub
, pkg-config
, dfu-programmer
, gtk3
, hidapi
, libxml2
}:

stdenv.mkDerivation rec {
  pname = "gcn64tools";
  version = "2.1.27";

  src = fetchFromGitHub {
    owner = "raphnet";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-3VrLZDW5qzj/EL7+KxgjVw/W3fLoeQ1stVjLeEZm0sA=";
  };

  sourceRoot = "source/src";

  postPatch = ''
    substituteInPlace gui_fwupd.c \
      --replace '"../firmwares"' "\"$out/lib/gcn64tools/firmwares\""
  '';

  makeFlags = [ "PREFIX=$(out)" ];
  preInstall = ''
    mkdir -p $out/bin
  '';
  postInstall = ''
    mkdir -p $out/lib/udev/rules.d
    cp ../scripts/*.rules $out/lib/udev/rules.d
    mkdir -p $out/lib/gcn64tools/firmwares
    cp -R ../firmwares/* $out/lib/gcn64tools/firmwares
  '';

  hardeningDisable = [
    "format"
  ];

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    dfu-programmer
    gtk3
    hidapi
    libxml2
  ];

  meta = with lib; {
    description = "Raphnet USB adapter management tools";
    homepage = "https://www.raphnet.net/programmation/gcn64tools/index_en.php";
    license = with licenses; [ gpl3 ];
  };
}
