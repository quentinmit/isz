{ gradle2nix
, zulu25
, fetchFromGitHub
, makeWrapper
, wrapGAppsHook3
, lib
}:
let
  jdk = zulu25.override { enableJavaFX = true; };
  pname = "sdrtrunk";
  version = "0.6.1+20260219";
in gradle2nix.buildGradlePackage {
  inherit pname version;
  lockFile = ./gradle.lock;
  gradleInstallFlags = [ "installDist" ];
  buildJdk = jdk;

  nativeBuildInputs = [
    makeWrapper
    wrapGAppsHook3
  ];

  src = fetchFromGitHub {
    owner = "DSheirer";
    repo = pname;
    rev = "a053315675e6764fe95c671139d796893c2b41a1";
    hash = "sha256-mafJUMZZQSSCZdJ1RFGCa4J2IJXOrtuXalMS7HVI5OI=";
  };

  postInstall = ''
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
