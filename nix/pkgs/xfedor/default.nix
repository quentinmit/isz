{
  lib,
  stdenv,
  fetchurl,
  imake,
  gccmakedep,
  libx11,
  libxext,
  libxpm,
  byacc,
  flex,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "xfedor";
  version = "6";

  __structuredAttrs = true;

  src = fetchurl {
    url = "https://xorg.freedesktop.org/archive/X11R${finalAttrs.version}/contrib-2.tar.gz";
    hash = "sha256-uc+ht9lNEkVWpq8hfkoO7s4En0AmVQzfWsk83vGW0aA=";
  };

  sourceRoot = "contrib/programs/${finalAttrs.pname}";

  postPatch = ''
    substituteInPlace Imakefile \
      --replace-fail ComplexProgramTarget ComplexProgramTargetNoMan
    substituteInPlace couchex.c \
      --replace-fail '"xpm.h"' '<X11/xpm.h>'
    sed -i -e $'1i\\\nstatic Rast(int);' tr_garb.c
    sed -i -e $'1i\\\nstatic int Aff_item(int,int);\\\nstatic int AffMax_item(char,int,int);' tr_num.c
    sed -i -e $'1i\\\nstatic int Aff_item(int,char*);' tr_save.c
    sed -i -e $'1i\\\nstatic Aff_mode();\\\nstatic Aff_code(int);\\\nstatic Aff_first();\\\nstatic Aff_last();' tr_font.c
    sed -i -e $'1i\\\nstatic Afficher_modcolor(int);\\\nstatic Afficher_modecour();' tr_edit.c
    sed -i -e $'1i\\\n#include <string.h>\\\n' -e $'/fedor.h/a\\\nstatic prefix(char*,char*);\\\nstatic int ReadFont(char*,fedchar*,BdfHeader*,int*);' -e 's/getline/getline2/' filer.c
    sed -i -e $'/fedor.h/a\\\nstatic int Get_fedchar(char*,fedchar*,int);' bitmap.c
  '';

  nativeBuildInputs = [
    imake
    gccmakedep
    byacc
    flex
  ];

  buildInputs = [
    libx11
    libxext
    libxpm
    flex
  ];

  env.NIX_CFLAGS_COMPILE = "-std=gnu89";

  makeFlags = [
    "SYS_LIBRARIES=-lm -Wl,-allow-multiple-definition"
  ];

  installFlags = [
    "DESTDIR=$(out)/"
    "BINDIR=bin"
  ];

  installTargets = [
    "install"
  ];

  meta = {
    mainProgram = "xfedor";
    maintainers = with lib.maintainers; [ quentin ];
    license = lib.licenses.x11;
    platforms = lib.platforms.unix;
  };
})
