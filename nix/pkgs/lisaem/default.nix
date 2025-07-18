{
  fetchFromGitHub,
  which,
  wxGTK32,
  wrapGAppsHook3,
  stdenv,
  lib,
  withDebug ? false,
}:
let
  pname = "lisaem";
  version = "RC5-2025.03.15";
in
stdenv.mkDerivation {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "arcanebyte";
    repo = pname;
    rev = version;
    hash = "sha256-F0Go8BithBUhE8I2VSJ850xexSRKV+xxIgRZlr2L3Z8=";
  };

  postPatch = ''
    substituteInPlace \
      build.sh \
      src/tools/build.sh \
      src/lib/TerminalWx/build.sh \
      src/lib/libGenerator/build.sh \
      src/lib/libdc42/build.sh \
      src/lib/libdc42/tester/build.sh \
      bashbuild/save-restore-env.fn \
      bashbuild/compilequeue.fn \
      bashbuild/checkdirs.fn \
      bashbuild/progressbar.fn \
      bashbuild/src.build \
      bashbuild/buildphase.fn \
      --replace-fail /bin/pwd pwd
    substituteInPlace \
      bashbuild/compilequeue.fn \
      --replace-fail /usr/bin/tty tty \
      --replace-fail "/usr/bin/env bash" "${stdenv.shell}"
    substituteInPlace \
      src/tools/build.sh \
      src/lib/TerminalWx/build.sh \
      src/lib/libGenerator/build.sh \
      src/lib/libdc42/build.sh \
      src/lib/libdc42/tester/build.sh \
      bashbuild/*.sys \
      --replace-fail /bin/rm rm
    substituteInPlace \
      build.sh \
      --replace-fail '-z "$WITHDEBUG"' 1 \
      --replace-fail 'INSTALL=""' ""
    substituteInPlace \
      src/host/wxui/lisaem_wx.cpp \
      --replace-fail 'display(my_lisaframe)' 'display(parent)' \
      --replace-fail 'DCTYPE dc(this);
        dc.SetUserScale(hidpi_scale, hidpi_scale);' "" \
      --replace-fail 'tick:%d' 'tick:%ld'

    cat > bashbuild/Linuxzz.sys <<EOF
    export PREFIX=$out/bin
    export PREFIXLIB=$out/share/
    EOF
  '';

  buildInputs = [
    wxGTK32
  ];

  nativeBuildInputs = [
    which
    wrapGAppsHook3
  ];

  # bashbuild/save-restore-env.fn fails if any env variables contain newlines
  # __structuredAttrs means that derivation values don't become env vars
  __structuredAttrs = true;

  dontConfigure = true;

  env.CFLAGS = "-D_DEFAULT_SOURCE -D_XOPEN_SOURCE=600";

  env.GDB = "true";
  buildFlags = [
    "--showcmd"
  ] ++ lib.optional withDebug "--debug";
  installFlags = [
    "--showcmd"
  ] ++ lib.optional withDebug "--debug";
  hardeningDisable = [
    "format"
  ];

  buildPhase = ''
    runHook preBuild

    local flagsArray=()
    concatTo flagsArray buildFlags buildFlagsArray
    ${stdenv.shell} build.sh "''${flagsArray[@]}"
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    local flagsArray=()
    concatTo flagsArray installFlags installFlagsArray
    INSTALL=1 ${stdenv.shell} build.sh "''${flagsArray[@]}"
    runHook postInstall
  '';

  dontStrip = true;

  meta = with lib; {
    description = "The first fully functional Lisa Emulator";
    homepage = "https://github.com/arcanebyte/lisaem";
    license = licenses.gpl3;
    maintainers = with maintainers; [ quentin ];
  };
}
