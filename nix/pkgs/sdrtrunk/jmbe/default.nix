{ callPackage
, fetchFromGitHub
, gradleGen
, gradle_7
, jdk11
, lib
}:
let
  buildGradle = callPackage ./gradle-env.nix {
    gradleGen = { ... }: {}: gradle_7;
  };
  jdk = jdk11;
  version = "1.0.9";
in buildGradle {
  envSpec = ./gradle-env.json;

  inherit version;

  buildJdk = jdk;

  src = fetchFromGitHub {
    owner = "DSheirer";
    repo = "jmbe";
    rev = "v${version}";
    hash = "sha256-70tjjMLyO7ooxVPaGV3m5BF0yY9nOLa0xjcBLB5JE7Y=";
  };

  gradleFlags = [ ":codec:build" ];

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
