{ gradle2nix
, fetchFromGitHub
, jdk
, lib
}:
let
  pname = "jmbe";
  version = "1.0.9";
in gradle2nix.buildGradlePackage {
  inherit pname version;
  lockFile = ./gradle.lock;
  buildJdk = jdk;

  src = fetchFromGitHub {
    owner = "DSheirer";
    repo = "jmbe";
    rev = "v${version}";
    hash = "sha256-70tjjMLyO7ooxVPaGV3m5BF0yY9nOLa0xjcBLB5JE7Y=";
  };

  gradleBuildFlags = [ ":codec:build" ];

  installPhase = ''
    mkdir $out
    cp codec/build/libs/jmbe-*.jar $out
  '';

  meta = with lib; {
    description = "Java AMBE/IMBE audio decoder";
    homepage = "https://github.com/DSheirer/jmbe/";
    license = licenses.gpl3;
    maintainer = maintainers.quentin;
  };
}
