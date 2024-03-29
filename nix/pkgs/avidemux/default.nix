{ stdenv, lib, fetchurl, cmake, pkg-config
, zlib, gettext, libvdpau, libva, libXv, sqlite
, yasm, freetype, fontconfig, fribidi
, makeWrapper, libXext, libGLU, qttools, qtbase, wrapQtAppsHook
, alsa-lib
, VideoToolbox, CoreFoundation, CoreMedia, CoreVideo, CoreAudio, CoreServices, QuartzCore
, withX265 ? true, x265
, withX264 ? true, x264
, withXvid ? true, xvidcore
, withLAME ? true, lame
, withFAAC ? false, faac
, withVorbis ? true, libvorbis
, withPulse ? true, libpulseaudio
, withFAAD ? true, faad2
, withOpus ? true, libopus
, withVPX ? true, libvpx
, withQT ? true
, withCLI ? true
, default ? "qt5"
, withPlugins ? true
}:

assert withQT -> qttools != null && qtbase != null;
assert default != "qt5" -> default == "cli";
assert !withQT -> default != "qt5";

stdenv.mkDerivation rec {
  pname = "avidemux";
  version = "2.8.1";

  src = fetchurl {
    url = "mirror://sourceforge/avidemux/avidemux/${version}/avidemux_${version}.tar.gz";
    sha256 = "sha256-d9m9yoaDzlfBkradIHz6t8+Sp3Wc4PY/o3tcjkKtPaI=";
  };

  patches = [
    ./dynamic_install_dir.patch
    ./bootstrap_logging.patch
  ];

  # ffmpeg doesn't build on a case-sensitive filesystem due to VERSION colliding
  # with the new C++ <version> header.
  postPatch = lib.optionalString stdenv.isDarwin ''
    sed -i '/FFMPEG_PERFORM_PATCH 1/i\
    file(REMOVE "\''${FFMPEG_SOURCE_DIR}/VERSION")' \
    cmake/admFFmpegPrepareTar.cmake
    sed -i '/export EXTRA=/a\
    export EXTRA="$EXTRA -DCMAKE_INSTALL_RPATH=$out/lib"' \
    bootStrap.bash
  '';

  CXXFLAGS = lib.optionalString stdenv.isDarwin "-Wno-c++11-narrowing";

  nativeBuildInputs =
    [ yasm cmake pkg-config makeWrapper ]
    ++ lib.optional withQT wrapQtAppsHook;
  buildInputs = [
    zlib gettext libvdpau libXv sqlite fribidi fontconfig
    freetype libXext libGLU
  ] ++ lib.optionals stdenv.isLinux [ libva alsa-lib ]
    ++ lib.optionals stdenv.isDarwin [ VideoToolbox CoreFoundation CoreMedia CoreVideo CoreAudio CoreServices QuartzCore ]
    ++ lib.optional withX264 x264
    ++ lib.optional withX265 x265
    ++ lib.optional withXvid xvidcore
    ++ lib.optional withLAME lame
    ++ lib.optional withFAAC faac
    ++ lib.optional withVorbis libvorbis
    ++ lib.optional withPulse libpulseaudio
    ++ lib.optional withFAAD faad2
    ++ lib.optional withOpus libopus
    ++ lib.optionals withQT [ qttools qtbase ]
    ++ lib.optional withVPX libvpx;

  buildCommand = let
    wrapWith = makeWrapper: filename:
      "${makeWrapper} ${filename} --set ADM_ROOT_DIR $out --prefix LD_LIBRARY_PATH : ${libXext}/lib";
    wrapQtApp = wrapWith "wrapQtApp";
    wrapProgram = wrapWith "wrapProgram";
    binNames = if stdenv.isDarwin then {
      cli = "avidemux_cli";
      qt5 = "Avidemux${lib.versions.majorMinor version}";
      jobs = "avidemux_jobs";
    } else {
      cli = "avidemux3_cli";
      qt5 = "avidemux3_qt5";
      jobs = "avidemux3_jobs_qt5";
    };
  in ''
    unpackPhase
    cd "$sourceRoot"
    patchPhase

    ${stdenv.shell} bootStrap.bash \
      --with-core \
      --prefix="$out" \
      ${if withQT then "--with-qt" else "--without-qt"} \
      ${if withCLI then "--with-cli" else "--without-cli"} \
      ${if withPlugins then "--with-plugins" else "--without-plugins"}

    mkdir $out
    cp -R install/$out/* $out

    ${wrapProgram "$out/bin/${binNames.cli}"}

    ${lib.optionalString withQT ''
      ${wrapQtApp "$out/bin/${binNames.qt5}"}
      ${wrapQtApp "$out/bin/${binNames.jobs}"}
    ''}

    ln -s "$out/bin/${binNames.${default}}" "$out/bin/avidemux"

    fixupPhase
  '';

  meta = with lib; {
    homepage = "http://fixounet.free.fr/avidemux/";
    description = "Free video editor designed for simple video editing tasks";
    maintainers = with maintainers; [ abbradar ];
    # "CPU not supported" errors on AArch64
    platforms = [ "i686-linux" "x86_64-linux" ] ++ platforms.darwin;
    license = licenses.gpl2;
  };
}
