{
  platformio,
  cacert,
  pkg-config,
  bluez,
  libinput,
  i2c-tools,
  libgpiod,
  libusb1,
  libuv,
  libxkbcommon,
  libX11,
  yaml-cpp,
  stdenv,
  gccStdenv,
  stdenvNoCC,
  fetchFromGitHub,
}:
let
  version = "2.6.11.60ec05e";
  src = fetchFromGitHub {
    owner = "meshtastic";
    repo = "firmware";
    rev = "v${version}";
    hash = "sha256-91VDpEobokHTv7Vil/AibPnLIawoOWK525FhmRdlicM=";
  };
  depsHash = "sha256-C+ZIHLFC+tLQXcujG1j2fF/UABm1O17G2isFv2PSlos=";
  pioCache = stdenvNoCC.mkDerivation {
    name = "meshtasticd-deps";
    inherit version src;
    nativeBuildInputs = [
      platformio
      cacert
    ];
    buildPhase = ''
      runHook preBuild
      PLATFORMIO_CORE_DIR=pio/core \
      PLATFORMIO_LIBDEPS_DIR=pio/libdeps \
	    PLATFORMIO_PACKAGES_DIR=pio/packages \
      platformio pkg install -e native-tft
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      find pio -name hooks | xargs rm -rf
      cp -a pio $out
      runHook postInstall
    '';
    dontFixup = true;
    outputHash = depsHash;
    outputHashAlgo = if depsHash == "" then "sha256" else null;
    outputHashMode = "recursive";
  };
in
gccStdenv.mkDerivation {
  name = "meshtasticd";
  inherit version src;

  nativeBuildInputs = [
    platformio
    pkg-config
  ];

  buildInputs = [
    bluez
    libinput
    libgpiod
    libxkbcommon
    i2c-tools
    libusb1
    libuv
    libX11
    yaml-cpp
  ];

  postPatch = ''
    substituteInPlace bin/meshtasticd.service \
      --replace-fail /usr $out
  '';

  buildPhase = ''
    runHook preBuild
    cp -R ${pioCache} pio
    chmod -R u+w pio
    ldflags=( $NIX_LDFLAGS )
    ldflags=''${ldflags[@]}
    ldflags=-Wl,''${ldflags// /,}
    PLATFORMIO_CORE_DIR=pio/core \
    PLATFORMIO_LIBDEPS_DIR=pio/libdeps \
	  PLATFORMIO_PACKAGES_DIR=pio/packages \
    PLATFORMIO_BUILD_FLAGS="$NIX_CFLAGS_COMPILE $ldflags" \
    platformio run -vv -e native-tft
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/etc/meshtasticd/available.d $out/lib/systemd/system $out/share/meshtasticd/web
    cp .pio/build/native-tft/program $out/bin/meshtasticd
    cp bin/config-dist.yaml $out/etc/meshtasticd/config.yaml
    cp bin/meshtasticd.service $out/lib/systemd/system/
    cp bin/config.d/* $out/etc/meshtasticd/available.d/
    # TODO: Install web
    runHook postInstall
  '';

  passthru.pioCache = pioCache;
}
