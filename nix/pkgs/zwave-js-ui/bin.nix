{ stdenv, lib, fetchzip, glibc, gcc-unwrapped, autoPatchelfHook, bbe, nix-update-script }:
stdenv.mkDerivation rec {
  pname = "zwave-js-ui-bin";
  version = "9.32.0";

  src = fetchzip {
    url = "https://github.com/zwave-js/zwave-js-ui/releases/download/v${version}/zwave-js-ui-v${version}-linux.zip";
    stripRoot = false;
    hash = "sha256-fbg1VsOBFkuCizF3GUDAXAIsXuvidjPqH3qI72MuW9M=";
  };

  # Required for compilation
  nativeBuildInputs = [
    autoPatchelfHook # Automatically setup the loader, and do the magic
    bbe
  ];

  # Required at running time
  buildInputs = [
    glibc
    gcc-unwrapped
  ];

  unpackPhase = "true";

  dontStrip = true;

  # Extract and copy executable in $out/bin
  installPhase = ''
    mkdir -p $out/bin
    cp -av $src/zwave-js-ui-linux $out/bin/zwave-js-ui-tmp
  '';

  preFixup = ''
    addoffset() {
      local var="$1"
      local offset="$2"
      local start="var $var = '"
      local old_value="$(bbe -s -b "/$start/:/'/" -e "s/$start//" -e "s/'//" $src/zwave-js-ui-linux)"
      local new_value="$(printf "%-''${#old_value}d" "$((old_value + offset))")"
      bbe -b "/$start/:/'/" -e "r ''${#start} $new_value"
    }

    fixoffsets() {
      local old_length=$(wc -c $src/zwave-js-ui-linux | awk '{ print $1 }')
      local new_length=$(wc -c $out/bin/zwave-js-ui-tmp | awk '{ print $1 }')
      local offset=$((new_length - old_length))
      echo "Adding offset $offset to payload and prelude position"
      cat $out/bin/zwave-js-ui-tmp | addoffset PAYLOAD_POSITION "$offset" | addoffset PRELUDE_POSITION "$offset" > $out/bin/zwave-js-ui
      chmod +x $out/bin/zwave-js-ui
      rm $out/bin/zwave-js-ui-tmp
    }
    postFixupHooks+=(fixoffsets)
  '';

  passthru.updateScript = nix-update-script;

  meta = with lib; {
    description = "Z-Wave JS UI";
    longDescription = ''
      Full featured Z-Wave Control Panel UI and MQTT gateway. Built using
      Nodejs, and Vue/Vuetify.
    '';
    homepage = "https://zwave-js.github.io/zwave-js-ui/";
    license = with licenses; [ mit ];
    platforms = [ "x86_64-linux" ];
  };
}
