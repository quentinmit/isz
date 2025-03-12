{ gradle2nix
, jdk23
, fetchFromGitHub
, makeWrapper
, wrapGAppsHook3
, lib
}:
let
  jdk = jdk23.override { enableJavaFX = true; };
  pname = "sdrtrunk";
  version = "0.6.1";
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
    rev = "v${version}";
    hash = "sha256-5cklAqO7KyDdkQM0fCZTT8DHsZx/Tf0c8B9TiLMLrkA=";
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
