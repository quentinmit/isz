{ lib, stdenv, buildEnv, makeFontsConf, gnused, writeScript, xorg, bashInteractive, xterm, xcbuild, makeWrapper
, quartz-wm, fontconfig, xlsfonts, xfontsel
, ttf_bitstream_vera, freefont_ttf, liberation_ttf
, nixpkgs
, shell ? "${bashInteractive}/bin/bash"
}:

stdenv.mkDerivation {
  pname = "xquartz";
  version = lib.getVersion xorg.xorgserver;

  nativeBuildInputs = [ makeWrapper ];

  unpackPhase = "sourceRoot=.";

  dontBuild = true;

  installPhase = ''
    set -x
    # xinit provides startx and xinit
    cp -rT ${xorg.xinit} $out
    chmod -R u+w $out
    cp -rT ${xorg.xorgserver} $out
    chmod -R u+w $out

    substituteInPlace $out/bin/startx \
      --replace "bindir=${xorg.xinit}/bin" "bindir=$out/bin"

    fontsConfPath=/etc/X11/fonts.conf

    cp ${nixpkgs}/pkgs/servers/x11/xquartz/font_cache $out/bin/font_cache
    substituteInPlace $out/bin/font_cache \
      --subst-var-by "shell"           "${stdenv.shell}" \
      --subst-var-by "PATH"            "$out/bin" \
      --subst-var-by "ENCODINGSDIR"    "${xorg.encodings}/share/fonts/X11/encodings" \
      --subst-var-by "MKFONTDIR"       "${xorg.mkfontdir}/bin/mkfontdir" \
      --subst-var-by "MKFONTSCALE"     "${xorg.mkfontscale}/bin/mkfontscale" \
      --subst-var-by "FC_CACHE"        "${fontconfig.bin}/bin/fc-cache" \
      --subst-var-by "FONTCONFIG_FILE" "$fontsConfPath"

    wrapProgram $out/bin/Xquartz \
      --set XQUARTZ_X11 $out/Applications/XQuartz.app/Contents/MacOS/X11

    ${xcbuild}/bin/PlistBuddy $out/Applications/XQuartz.app/Contents/Info.plist <<EOF
    Add :LSEnvironment dictionary
    Add :LSEnvironment:XQUARTZ_DEFAULT_CLIENT string "${xterm}/bin/xterm"
    Add :LSEnvironment:XQUARTZ_DEFAULT_SHELL string "${shell}"
    Add :LSEnvironment:XQUARTZ_DEFAULT_STARTX string "$out/bin/startx"
    Add :LSEnvironment:FONTCONFIG_FILE string "$fontsConfPath"
    Save
    EOF

    mkdir -p $out/etc/X11/xinit/xinitrc.d

    cat > $out/etc/X11/xinit/xinitrc.d/99-quartz-wm.sh <<EOF
    exec ${quartz-wm}/bin/quartz-wm
    EOF

    substituteInPlace $out/etc/X11/xinit/xinitrc \
      --replace ${xorg.xinit} $out
    set +x
  '';
}
