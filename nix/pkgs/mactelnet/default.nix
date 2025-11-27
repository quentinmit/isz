{ stdenv
, gettext
, automake
, autoconf
, openssl
, pkg-config
, fetchFromGitHub
, lib
}:
let
  version = "0.6.1";
in stdenv.mkDerivation {
  pname = "mactelnet";
  inherit version;

  src = fetchFromGitHub {
    owner = "haakonnessjoen";
    repo = "MAC-Telnet";
    rev = "v${version}";
    hash = "sha256-gKr3URYKuH4SxpU6DSCtmb7gGiEgO2agBEJOJFdy9q0=";
  };

  nativeBuildInputs = [
    gettext
    automake
    autoconf
    pkg-config
  ];

  buildInputs = [
    openssl
  ];

  prePatch = ''
    sed -i /chown/d config/Makefile.am
  '';

  configureScript = "./autogen.sh";
}
