{ lib, stdenv, fetchurl, cpio, xar, undmg, fixDarwinDylibNames, signingUtils }:

stdenv.mkDerivation rec {
  pname = "macfuse";
  version = "4.4.3";

  src = fetchurl {
    url = "https://github.com/osxfuse/osxfuse/releases/download/macfuse-${version}/macfuse-${version}.dmg";
    sha256 = "32YR5QHB9ayDjy/rqoqUnM13RM69A9uczfpGrsBMnSc=";
  };

  nativeBuildInputs = [ cpio xar undmg signingUtils fixDarwinDylibNames ];

  postUnpack = ''
    xar -xf 'Install macFUSE.pkg'
    cd Core.pkg
    gunzip -dc Payload | cpio -i
  '';

  sourceRoot = ".";

  buildPhase = ''
    pushd usr/local/lib
    #for f in *.dylib; do
    #  tapi stubify --filetype=tbd-v2  "$f" -o "''${f%%.dylib}.tbd"
    #done
    sed -i "s|^prefix=.*|prefix=$out|" pkgconfig/fuse.pc
    popd
  '';

  # Modifying the .fs will invalidate the code signature.
  dontPatchShebangs = true;

  # NOTE: Keep in mind that different parts of macFUSE are distributed under a
  # different license
  installPhase = ''
    mkdir -p $out/include $out/lib/pkgconfig $out/Library
    cp -R Library/* $out/Library
    cp -R usr/local/lib/* $out/lib
    cp -R usr/local/include/* $out/include
  '';

  postFixup = ''
    sign $out/lib/libfuse.2.dylib
  '';

  meta = with lib; {
    homepage = "https://osxfuse.github.io";
    description = "FUSE on macOS";
    platforms = platforms.darwin;
  };
}
