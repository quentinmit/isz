{ stdenv, fetchzip, glibc, gcc-unwrapped, autoPatchelfHook }:
let
  src = fetchzip {
    url = "https://github.com/zwave-js/zwave-js-ui/releases/download/v8.11.0/zwave-js-ui-v8.11.0-linux.zip";
    sha256 = "";
  };

  version = "8.11.0";
in stdenv.mkDerivation {
  name = "zwave-js-ui-bin";

  inherit src;
  inherit version;

  # Required for compilation
  nativeBuildInputs = [
    autoPatchelfHook # Automatically setup the loader, and do the magic
  ];

  # Required at running time
  buildInputs = [
    glibc
    gcc-unwrapped
  ];

  unpackPhase = "true";

  # Extract and copy executable in $out/bin
  installPhase = ''
    mkdir -p $out
    cp -av $src/zwave-js-ui-linux $out/bin/zwave-js-ui
  '';


  meta = with lib; {
    description = "Z-Wave JS UI";
    longDescription = ''
      Full featured Z-Wave Control Panel UI and MQTT gateway. Built using
      Nodejs, and Vue/Vuetify.
    '';
    homepage = https://zwave-js.github.io/zwave-js-ui/;
    license = with licenses; [ mit ];
    platforms = [ "x86_64-linux" ];
  };
}
