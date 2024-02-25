{ lib
, buildGoModule
, fetchFromGitHub
, makeWrapper
, google-chrome
, libreoffice
# , unoconverter
, pdftk
, qpdf
, libreoffice-args
, unoconverter
}:
buildGoModule rec {
  pname = "gotenberg";
  version = "8.2.0";

  src = fetchFromGitHub {
    owner = "gotenberg";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-xu3ttYWk+DG0B35MhiEPtxSdLK4U38PsRbNkLx7tBAs=";
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
      --replace /tests/ $PWD/
  '';

  vendorHash = "sha256-VMosd8I70cLSEJV6q+2xeMooGCJ/s/I3jfOWTU2ZYn8=";

  nativeBuildInputs = [ makeWrapper ];

  preCheck = ''
    export XDG_CACHE_HOME="$(mktemp -d)"
    cp "${libreoffice-args.fontsConf}" fonts.conf
    export FONTCONFIG_FILE="$PWD/fonts.conf"
  '';

  env = {
    CHROMIUM_BIN_PATH = "${google-chrome}/bin/google-chrome-stable";
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
