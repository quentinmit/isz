{ stdenv
, lib
, python3
, uglify-js
, fetchFromGitHub
}:
let
  pname = "xpra-html5";
  version = "11.2";
in stdenv.mkDerivation {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "Xpra-org";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-KwvFZXKOSBIEDZ8RDFkgRLwa3hOU7pS8a0BQgtmBL8U=";
  };

  nativeBuildInputs = [
    python3
    uglify-js
  ];

  installPhase = ''
    python3 setup.py install / $out/share/xpra/www $out/etc/xpra/html5-client uglifyjs
  '';
}
