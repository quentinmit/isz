{ lib
, stdenv
, gettext
, dpkg
, perlPackages
, fetchFromGitLab
}:
let
  inherit (perlPackages) perl;
in stdenv.mkDerivation rec {
  pname = "debhelper";
  version = "13.19";

  src = fetchFromGitLab {
    domain = "salsa.debian.org";
    owner = "debian";
    repo = "debhelper";
    rev = "debian/${version}";
    hash = "sha256-H+A+Z25dU8HLw+jCgpOtJ6Mu9zG6X7SX8yv6iLpktj4=";
  };

  patchPhase = ''
    patchShebangs .
  '';

  nativeBuildInputs = [
    gettext
  ] ++ (with perlPackages; [
    perl
    Po4a
  ]);

  propagatedBuildInputs = [
    dpkg
  ];

  makeFlags = [
    "PREFIX=$(out)"
    "PERLLIBDIR=$(out)/${perl.libPrefix}/Debian/Debhelper"
  ];

  postInstall = ''
    PERL5LIB="$PERL5LIB''${PERL5LIB:+:}$out/${perl.libPrefix}"

    perlFlags=
    for i in $(IFS=:; echo $PERL5LIB); do
      perlFlags="$perlFlags -I$i"
    done

    find $out/bin | while read fn; do
        if test -f "$fn"; then
            first=$(dd if="$fn" count=2 bs=1 2> /dev/null)
            if test "$first" = "#!"; then
                echo "patching $fn..."
                sed -i "$fn" -e "s|^#\!\(.*\bperl\b.*\)$|#\!\1$perlFlags|"
            fi
        fi
    done
  '';

  meta = with lib; {
    description = "";
    homepage = "https://salsa.debian.org/debian/debhelper.git";
    license = licenses.gpl2Plus;
    maintainers = with maintainers; [ quentin ];
    mainProgram = "dh";
    platforms = platforms.all;
  };
}
