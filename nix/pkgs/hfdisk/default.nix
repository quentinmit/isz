{ stdenv
, lib
, fetchFromGitHub
}:
let
  pname = "hfdisk";
  version = "2022.11";
in stdenv.mkDerivation {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "rdmark";
    repo = pname;
    tag = version;
    hash = "sha256-3/xEsUA0TM6++8bP638lp2qJMYXt7wfpzgNUtPDjf9s=";
  };

  installPhase = ''
    mkdir -p $out/bin
    cp hfdisk $out/bin/hfdisk
  '';

  meta = with lib; {
    description = "Tools for reading and writing Macintosh volumes";
    homepage = "https://github.com/rdmark/hfdisk";
    license = licenses.mit;
    maintainers = [ maintainers.quentin ];
    platforms = platforms.unix;
    mainProgram = "hfdisk";
  };
}
