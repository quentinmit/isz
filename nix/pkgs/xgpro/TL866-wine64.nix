{
  stdenv,
  libusb1,
  pkgsCross,
  fetchFromGitHub,
  lib,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "TL866-wine64";
  version = "0.1";
  src = fetchFromGitHub {
    owner = "radiomanV";
    repo = "TL866";
    rev = "ffd1a826f41443bac8a7e97a8e69754e6dbff131";
    sparseCheckout = [
      "wine64"
    ];
    hash = "sha256-8G2DD+DkMeBMMNbQq4U88RJO2XLMZNbE1PETzMvmLmw=";
  };
  sourceRoot = "${finalAttrs.src.name}/wine64";

  buildInputs = [
    libusb1
  ];
  nativeBuildInputs = [
    pkgsCross.mingw32.buildPackages.gcc
  ];
  #NIX_DEBUG = 7;
  preBuild = ''
    make clean
  '';
  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp run.sh shim.dll launcher.exe usb-broker $out

    runHook postInstall
  '';
  meta = with lib; {
    maintainer = with maintainers; [ quentin ];
    license = licenses.gpl2Only;
  };
})
