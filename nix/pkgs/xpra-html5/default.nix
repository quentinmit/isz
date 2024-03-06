{ stdenv
, lib
, python3
, uglify-js
, fetchFromGitHub
}:
let
  pname = "xpra-html5";
  version = "8.1";
in stdenv.mkDerivation {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "Xpra-org";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-HITQD3CeOcz6Gw9ZpwWOEukY6A8gwwDAp62Ytb0vt1o=";
  };

  nativeBuildInputs = [
    python3
    uglify-js
  ];

  installPhase = ''
    python3 setup.py install / $out/share/xpra/www $out/etc/xpra/html5-client uglifyjs
  '';
}
