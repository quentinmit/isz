{ lib
, stdenvNoCC
, fetchzip
, makeWrapper
, electron
}:

# Based on https://github.com/flathub/com.boxy_svg.BoxySVG/blob/master/com.boxy_svg.BoxySVG.yaml

let
  version = "4.95.0";
in stdenvNoCC.mkDerivation {
  pname = "boxy-svg";
  inherit version;

  src = fetchzip {
    url = "https://storage.boxy-svg.com/builds/boxy-svg-v${version}-linux-x64.zip";
    hash = "sha256-lnf+A4SZEMUA7mXtl3LgASOnLjWjP6khIjInSsXttnU=";
  };

  nativeBuildInputs = [
    makeWrapper
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/boxy-svg
    cp resources/app.asar $out/share/boxy-svg/
    makeWrapper '${electron}/bin/electron' "$out/bin/boxy-svg" \
      --add-flags "$out/share/boxy-svg/app.asar" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}" \
      --inherit-argv0
    install -Dm644 metadata/com.boxy_svg.BoxySVG.desktop     $out/share/applications/com.boxy_svg.BoxySVG.desktop
    install -Dm644 metadata/com.boxy_svg.BoxySVG.svg         $out/share/icons/hicolor/scalable/apps/com.boxy_svg.BoxySVG.svg
    install -Dm644 metadata/com.boxy_svg.BoxySVG.png         $out/share/icons/hicolor/128x128/apps/com.boxy_svg.BoxySVG.png
    runHook postInstall
  '';

  meta = with lib; {
    description = "Scalable Vector Graphics (SVG) editor";
    homepage = "https://boxy-svg.com/";
    license = licenses.unfree;
    maintainers = [ maintainers.quentin ];
    platforms = platforms.linux;
  };
}
