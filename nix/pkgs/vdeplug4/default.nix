{
  cmake,
  stdenv,
  fetchFromGitHub,
  libexecs,
  libpcap,
  mbedtls,
}: let
  pname = "vdeplug4";
  version = "4.0.1-git";
in stdenv.mkDerivation {
  inherit pname version;
  src = fetchFromGitHub {
    owner = "rd235";
    repo = pname;
    rev = "a595069806e756b7597d3629d404848289b61d2c";
    hash = "sha256-BSKHwo4fFsRAirlRVb/N50c/8ROuDLk7EChXjWLjHdU=";
  };
  nativeBuildInputs = [
    cmake
  ];
  buildInputs = [
    libexecs
    libpcap
    mbedtls
  ];
}
