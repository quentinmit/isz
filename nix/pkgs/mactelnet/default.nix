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
  version = "0.6.3";
in stdenv.mkDerivation {
  pname = "mactelnet";
  inherit version;

  src = fetchFromGitHub {
    owner = "haakonnessjoen";
    repo = "MAC-Telnet";
    rev = "v${version}";
    hash = "sha256-2vCzfAycrsr6oZkifp/fcs8Q8EixhfmcMttb8kMfn+k=";
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
