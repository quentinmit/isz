{ lib
, buildGoModule
, fetchFromGitHub
, makeWrapper
, exiftool
, google-chrome
, libreoffice
, pdftk
, qpdf
, unoconverter
}:
buildGoModule rec {
  pname = "gotenberg";
  version = "8.9.1";

  src = fetchFromGitHub {
    owner = "gotenberg";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-y54DtOYIzFAk05TvXFcLdStfAXim3sVHBkW+R8CrtMM=";
  };

  patches = [
    ./tempdir.patch
  ];

  postPatch = ''
    substituteInPlace \
      pkg/modules/api/{context,formdata,api,middlewares}_test.go \
      pkg/modules/pdfcpu/pdfcpu_test.go \
      pkg/modules/pdftk/pdftk_test.go \
      pkg/modules/qpdf/qpdf_test.go \
      pkg/modules/webhook/middleware_test.go \
      pkg/modules/exiftool/exiftool_test.go \
      --replace /tests/ $PWD/
  '';

  vendorHash = "sha256-BYcdqZ8TNEG6popRt+Dg5xW5Q7RmYvdlV+niUNenRG0=";

  nativeBuildInputs = [ makeWrapper ];

  preCheck = ''
    export XDG_CACHE_HOME="$(mktemp -d)"
    cp "${libreoffice.unwrapped.FONTCONFIG_FILE}" fonts.conf
    export FONTCONFIG_FILE="$PWD/fonts.conf"
  '';

  env = {
    CHROMIUM_BIN_PATH = "${google-chrome}/bin/google-chrome-stable";
    EXIFTOOL_BIN_PATH = "${exiftool}/bin/exiftool";
    LIBREOFFICE_BIN_PATH = "${libreoffice}/lib/libreoffice/program/soffice.bin";
    PDFTK_BIN_PATH = "${pdftk}/bin/pdftk";
    QPDF_BIN_PATH = "${qpdf}/bin/qpdf";
    UNOCONVERTER_BIN_PATH = "${unoconverter}/bin/unoconverter";
  };

  makeWrapperArgs = builtins.concatLists (lib.mapAttrsToList (name: value: ["--set" name value]) env);

  postInstall = ''
    wrapProgram $out/bin/gotenberg $makeWrapperArgs
  '';

  meta = with lib; {
    description = "A developer-friendly API for converting numerous document formats into PDF files, and more!";
    homepage = "https://github.com/gotenberg/gotenberg/";
    license = licenses.mit;
    maintainer = maintainers.quentin;
  };
}
