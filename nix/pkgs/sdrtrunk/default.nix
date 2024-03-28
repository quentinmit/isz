{ callPackage
, fetchFromGitHub
, gradleGen
, gradle
, jdk20
, makeWrapper
, wrapGAppsHook
, lib
}:
let
  buildGradle = callPackage ./gradle-env.nix {
    gradleGen = _: _: gradle;
  };
  jdk = jdk20.override { enableJavaFX = true; };
in buildGradle {
  envSpec = ./gradle-env.json;

  buildJdk = jdk;

  nativeBuildInputs = [
    makeWrapper
    wrapGAppsHook
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
    rm $out/bin/sdr-trunk.bat
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --set JAVA_HOME ${jdk.home}
    )
  '';

  meta = with lib; {
    description = "A cross-platform java application for decoding, monitoring, recording and streaming trunked mobile and related radio protocols using Software Defined Radios (SDR).";
    homepage = "https://github.com/DSheirer/sdrtrunk/";
    license = licenses.gpl3;
    maintainer = maintainers.quentin;
  };
}
