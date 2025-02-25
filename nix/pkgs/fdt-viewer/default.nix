{ stdenv
, cmake
, lib
, qtbase
, wrapQtAppsHook
, fetchFromGitHub
, git
}:

stdenv.mkDerivation {
  pname = "fdt-viewer";
  version = "0.8.2-pre";

  src = fetchFromGitHub {
    owner = "dev-0x7C6";
    repo = "fdt-viewer";
    rev = "3488a599bfe0a92a0aec3cf421ef0c6f385f0737";
    hash = "sha256-THu6HZpVSqsU2M/5AVflTaW8l8FNSYVI/f1kbZ+zCsA=";
    fetchSubmodules = true;
  };

  buildInputs = [ qtbase ];
  nativeBuildInputs = [
    wrapQtAppsHook
    cmake
    git
  ];
}
