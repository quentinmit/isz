{
  lib,
  stdenv,
  fetchurl,
  imake,
  gccmakedep,
  libxt,
  libxext,
  byacc,
  flex,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "xfed";
  version = "6";

  __structuredAttrs = true;

  src = fetchurl {
    url = "https://xorg.freedesktop.org/archive/X11R${finalAttrs.version}/contrib-2.tar.gz";
    hash = "sha256-uc+ht9lNEkVWpq8hfkoO7s4En0AmVQzfWsk83vGW0aA=";
  };

  sourceRoot = "contrib/programs/${finalAttrs.pname}";

  nativeBuildInputs = [
    imake
    gccmakedep
    byacc
    flex
  ];

  buildInputs = [
    libxt
    libxext
    flex
  ];

  env.NIX_CFLAGS_COMPILE = "-std=gnu89";

  makeFlags = [
    "SYS_LIBRARIES=-lfl -Wl,-allow-multiple-definition"
  ];

  installFlags = [
    "DESTDIR=$(out)/"
    "BINDIR=bin"
    "MANDIR=man/man1"
  ];

  installTargets = [
    "install"
    "install.man"
  ];

  meta = {
    mainProgram = "xfed";
    maintainers = with lib.maintainers; [ quentin ];
    license = lib.licenses.x11;
    platforms = lib.platforms.unix;
  };
})
