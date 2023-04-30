{ lib
, stdenv
, fetchgit
, fetchpatch
, libsmi
}:

let
  libsmi-debian = libsmi.overrideAttrs (old: {
    patches = (old.patches or []) ++ [
      (fetchpatch {
        name = "smistrip.patch";
        url = "https://sources.debian.org/data/main/libs/libsmi/0.4.8%2Bdfsg2-16/debian/patches/smistrip.patch";
        sha256 = "qzHXqYdAXpfbIBEE6unVibrZdwXrWTH90i1UFKHAxeE=";
      })
    ];
  });
in stdenv.mkDerivation rec {
  pname = "snmp-mibs";
  version = "1.5";

  nativeBuildInputs = [
    libsmi
  ];

  src = fetchgit {
    url = "https://salsa.debian.org/debian/snmp-mibs-downloader.git";
    rev = "debian/${version}";
    sha256 = "QSl9Lr5a1irRlo3tsYQyN+UhrPAXs2bks2E26A2/iyo=";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    set -x
    mibdir=$out/share/snmp/mibs
    mkdir -p $mibdir
    for i in rfc ianarfc iana; do (
      . $src/$i.conf
      if [ "$ARCHTYPE" != "dirgz" ]; then
        echo "Only directories are supported"
        exit 1
      fi
      mkdir -p "$mibdir/$DEST"
      while read -r file mibs; do
        if [ "$file" != "#" ]; then
          if [ ! -z "$PREFIX" ]; then
            file="$PREFIX$file"
          fi
          if [ ! -z "$SUFFIX" ]; then
            file="$file$SUFFIX"
          fi
          cat $src/$ARCHIVE/$file | tr -d \\r \
            | ${libsmi-debian}/bin/smistrip -v -a -d "$mibdir/$DEST" -m "$mibs" -
        fi
      done < "$src/$CONF"
      if [ ! -z "$DIFF" ]; then
        patch -d "$mibdir/$DEST" <"$src/$DIFF"
      fi
    ) done
  '';
}
