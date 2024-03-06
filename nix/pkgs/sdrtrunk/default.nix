{ callPackage
, fetchFromGitHub
, gradleGen
, gradle
, jdk20
, makeWrapper
}:
let
  buildGradle = callPackage ./gradle-env.nix {
    gradleGen = { ... }: {}: gradle;
  };
  jdk = jdk20.override { enableJavaFX = true; };
in buildGradle {
  envSpec = ./gradle-env.json;

  buildJdk = jdk;

  nativeBuildInputs = [
    makeWrapper
  ];

  src = fetchFromGitHub {
    owner = "DSheirer";
    repo = "sdrtrunk";
    rev = "v0.6.1-beta-1";
    hash = "sha256-s3nrOZWmbgyIvtkI6AFRdESTBIOTpo+zLSTBFgDxpmY=";
  };

  gradleFlags = [ "installDist" ];

  installPhase = ''
    mv build/install/sdr-trunk "$out"
    wrapProgram $out/bin/sdr-trunk \
      --set JAVA_HOME ${jdk.home}
    rm $out/bin/sdr-trunk.bat
  '';
}
