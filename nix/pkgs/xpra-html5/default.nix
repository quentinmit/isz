{ stdenv
, lib
, python3
, uglify-js
, fetchFromGitHub
}:
let
  pname = "xpra-html5";
  version = "16.2";
in stdenv.mkDerivation {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "Xpra-org";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-ioA3ltY0J9a3jLOXkFwBI6HUDMqYUPyxRO5unOil8xY=";
  };

  nativeBuildInputs = [
    python3
    uglify-js
  ];

  installPhase = ''
    python3 setup.py install / $out/share/xpra/www $out/etc/xpra/html5-client uglifyjs
  '';
}
