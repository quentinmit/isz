{ stdenv
, gettext
, automake
, autoconf
, openssl
, pkg-config
, fetchFromGitHub
}:
stdenv.mkDerivation {
  pname = "mactelnet";
  version = "0.4.4-pre";

  src = fetchFromGitHub {
    owner = "haakonnessjoen";
    repo = "MAC-Telnet";
    rev = "c3dc4515b1aff09372cdb04aef393437dc2d8f60";
    hash = "sha256-EKs0x5YsmmVD/2Qrqzi3/OXHQc5VSPs+aJa7cLHtAD8=";
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
