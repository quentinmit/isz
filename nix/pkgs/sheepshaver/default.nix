{ stdenv
, basiliskii
, lib
, autoconf
, automake
, pkg-config
, perl
, file
, vde2
, SDL2
, gtk2
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "sheepshaver";
  inherit (basiliskii) version src patches;
  prePatch = ''
    cd ../../..
    chmod -R +w .
    cd BasiliskII/src/Unix
  '';
  postPatch = ''
    cd ../../..
    patch -p1 < ${./vde.patch}
    cd SheepShaver/src/Unix
  '';

  sourceRoot = "${finalAttrs.src.name}/SheepShaver/src/Unix";
  nativeBuildInputs = [
    autoconf
    automake
    pkg-config
    file
    perl
  ];
  buildInputs = [
    SDL2
    gtk2
    vde2
  ];
  preConfigure = ''
    NO_CONFIGURE=1 ./autogen.sh
    chmod +w ../MacOSX
  '';
  configureFlags = [
    "--enable-sdl-video"
    "--enable-sdl-audio"
    "--with-bincue"
    "--with-vdeplug"
    "--enable-addressing=direct"
  ];

  meta = with lib; {
    description = "PPC Macintosh emulator";
    homepage = "https://sheepshaver.cebix.net/";
    license = licenses.gpl2;
    maintainers = with maintainers; [ quentin ];
    platforms = platforms.linux;
    mainProgram = "SheepShaver";
  };
})
