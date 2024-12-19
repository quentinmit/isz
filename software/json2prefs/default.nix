{ stdenv
, jre
, jdk
, maven
, makeWrapper
}:
maven.buildMavenPackage {
  pname = "json2prefs";
  version = "1.0-SNAPSHOT";

  src = ./.;

  mvnHash = "sha256-20ZFZzDg942oua1JsY45FR+D86BkACRQ91Qc1QHXg7M=";

  nativeBuildInputs = [
    makeWrapper
  ];

  installPhase = ''
    mkdir -p $out/bin $out/share/json2prefs
    install -Dm644 target/json2prefs.jar $out/share/json2prefs
    makeWrapper ${jre}/bin/java $out/bin/json2prefs \
      --add-flags "-jar $out/share/json2prefs/json2prefs.jar"
  '';
}
