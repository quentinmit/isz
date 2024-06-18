{ stdenv
, gettext
, automake
, autoconf
, openssl
, pkg-config
, fetchFromGitHub
}:
let
  version = "0.5.1";
in stdenv.mkDerivation {
  pname = "mactelnet";
  inherit version;

  src = fetchFromGitHub {
    owner = "haakonnessjoen";
    repo = "MAC-Telnet";
    rev = "v${version}";
    hash = "sha256-/qcO2g84zNHRGUaIlcnBZiO3RtUqF9wyGjXROX4STqo=";
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
