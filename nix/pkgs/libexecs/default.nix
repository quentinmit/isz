{
  cmake,
  stdenv,
  fetchFromGitHub,
}: let
  pname = "libexecs";
  version = "1.4";
in stdenv.mkDerivation {
  inherit pname version;
  src = fetchFromGitHub {
    owner = "virtualsquare";
    repo = "s2argv-execs";
    rev = version;
    hash = "sha256-wFAxz2RUl3o05d1k2tWo0OyD06YUoHiIMoms8mxNNWA=";
  };
  nativeBuildInputs = [
    cmake
  ];
}
