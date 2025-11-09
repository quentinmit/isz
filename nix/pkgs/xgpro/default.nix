{
  lib,
  fetchurl,
  stdenvNoCC,
  runtimeShell,
  copyDesktopItems,
  makeDesktopItem,
  wineWowPackages,
  icoutils,
  unrar,
  glibcLocales,
  callPackage,
  writeText,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "xgpro";
  version = "12.96";

  src = fetchurl {
    url = "https://github.com/Kreeblah/XGecu_Software/raw/refs/heads/master/Xgpro/12/xgproV1296_Setup.rar";
    hash = "sha256-xmPj69m1m1R0sSOfyJbMReJPr65SH9VQIzzKzkfufro=";
  };

  TL866_wine64 = callPackage ./TL866-wine64.nix {};

  nativeBuildInputs = [
    unrar
    glibcLocales
    icoutils
    copyDesktopItems
  ];

  unpackPhase = ''
    runHook preUnpack

    unrar x $src
    LC_ALL=en_US.UTF-8 unrar x *.exe source/

    runHook postUnpack
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "xgpro";
      desktopName = "Xgpro";
      comment = finalAttrs.meta.description;
      exec = "xgpro";
      icon = "xgpro";
      categories = [
        "Development"
      ];
      startupWMClass = "Xgpro.exe";
    })
  ];

  buildPhase = ''
    runHook preBuild

    wrestool -x -t 14 -o xgpro.ico source/Xgpro.exe

    runHook postBuild
  '';

  regedits = writeText "xgpro.reg" ''
    Windows Registry Editor Version 5.00

    [HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ThemeManager]
    "ThemeActive"="0"
  '';

  # TODO: Figure out how to save user settings in the wine prefix while still running the app from the Nix store.

  launcher = ''
    #!${runtimeShell}
    wine=${wineWowPackages.stable}/bin/wine
    export WINEARCH=win64
    export WINEPREFIX="''${XGPRO_HOME:-"''${XDG_DATA_HOME:-"''${HOME}/.local/share"}/xgpro"}/wine"
    if [ ! -d "$WINEPREFIX" ] ; then
      mkdir -p "$WINEPREFIX"
      "$wine"boot --init
      "$wine" regedit ${finalAttrs.regedits}
      cp -R --no-preserve=mode @out@/lib/xgpro "$WINEPREFIX/drive_c/Program Files/Xgpro"
    fi

    PORT="''${BROKER_PORT:-35866}"
    BROKER="@wine64@/usb-broker"

    start_broker() {
      echo "Starting usb-broker: $BROKER --port $PORT"
      "$BROKER" --port "$PORT" --quiet &
      local bpid=$!
      echo "usb-broker PID=$bpid"
    }

    run_app() {
      "$wine" "@wine64@/launcher.exe" --exe "C:/Program Files/Xgpro/Xgpro.exe" --shim "shim.dll" -- "$@"
    }

    start_broker
    run_app "$@"
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/lib
    cp -R source $out/lib/xgpro
    substituteStream launcher launcher --replace-fail @out@ "$out" --replace-fail @wine64@ "$TL866_wine64" > $out/bin/xgpro
    chmod +x $out/bin/xgpro
    mkdir -p $out/share/icons/hicolor/{16x16,32x32}/apps
    icotool -x -i 1 -o $out/share/icons/hicolor/16x16/apps/xgpro.png xgpro.ico
    icotool -x -i 3 -o $out/share/icons/hicolor/32x32/apps/xgpro.png xgpro.ico
    runHook postInstall
  '';


  meta = with lib; {
    description = "XGecu programmer";
    homepage = "http://www.xgecu.com/EN/Index.html";
    downloadPage = "http://www.xgecu.com/EN/download.html";
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    license = licenses.unfree;
    maintainers = with maintainers; [ quentin ];
    inherit (wineWowPackages.stable.meta) platforms;
  };
})
