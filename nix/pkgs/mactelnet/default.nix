{ stdenv
, gettext
, automake
, autoconf
, openssl
, pkg-config
, SystemConfiguration
, fetchFromGitHub
, lib
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
  ] ++ lib.optionals stdenv.isDarwin [
    SystemConfiguration
  ];

  prePatch = ''
    sed -i /chown/d config/Makefile.am
  '';

  configureScript = "./autogen.sh";
}
