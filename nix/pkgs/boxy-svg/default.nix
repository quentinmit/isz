{ lib
, buildNpmPackage
, fetchzip
, makeWrapper
, electron
}:

# Based on https://github.com/flathub/com.boxy_svg.BoxySVG/blob/master/com.boxy_svg.BoxySVG.yaml

let
  version = "4.37.0";
in buildNpmPackage {
  pname = "boxy-svg";
  inherit version;

  src = fetchzip {
    url = "https://storage.boxy-svg.com/flathub/app-${version}.zip";
    hash = "sha256-tv/Js96zewsxtwzr15T2xgFXbEPQVdPdd/ULN+U+8P8=";
  };
  sourceRoot = "source/electron";

  npmDepsHash = "sha256-JDRsCiEIqV0bd7wecnkqNialaBWRP0Ypduu/4/bNSzA=";

  dontNpmBuild = true;

  nativeBuildInputs = [
    makeWrapper
  ];

  postInstall = ''
    makeWrapper '${electron}/bin/electron' "$out/bin/boxy-svg" \
      --add-flags "$out/lib/node_modules/boxy-svg" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}" \
      --inherit-argv0
    install -Dm644 ../metadata/com.boxy_svg.BoxySVG.desktop     $out/share/applications/com.boxy_svg.BoxySVG.desktop
    install -Dm644 ../metadata/com.boxy_svg.BoxySVG.svg         $out/share/icons/hicolor/scalable/apps/com.boxy_svg.BoxySVG.svg
    install -Dm644 ../metadata/com.boxy_svg.BoxySVG.png         $out/share/icons/hicolor/128x128/apps/com.boxy_svg.BoxySVG.png
  '';

  meta = with lib; {
    description = "Scalable Vector Graphics (SVG) editor";
    homepage = "https://boxy-svg.com/";
    license = licenses.unfree;
    maintainers = [ maintainers.quentin ];
    platforms = platforms.linux;
  };
}
