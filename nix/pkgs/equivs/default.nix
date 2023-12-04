{lib, stdenv, fetchurl
, makeWrapper, writeShellScript
, perlPackages, dpkg, debhelper, rsync
}:

stdenv.mkDerivation rec {
  version = "2.3.1";
  pname = "equivs";

  src = fetchurl {
    url = "mirror://debian/pool/main/e/equivs/equivs_${version}.tar.xz";
    hash = "sha256-BXf+KKRXIxT8pZr5U1hnBBtnmUR4bg5Qi6AeHDSQBsI=";
  };

  postPatch = ''
    substituteInPlace Makefile --replace pod2man ${perlPackages.perl}/bin/pod2man
    substituteInPlace usr/bin/equivs-build usr/bin/equivs-control --replace /usr/share $out/share --replace dpkg-buildpackage "${dpkg}/bin/dpkg-buildpackage --admindir $out/share/equivs/admindir" --replace "cp -R" "${rsync}/bin/rsync -rltE --chmod=u+w" --replace "cp " "cp --no-preserve=mode "
    substituteInPlace usr/share/equivs/template/debian/rules --replace "dh \$@" "dh \$@ --without autoreconf"
    cat >>usr/share/equivs/template/debian/rules <<EOF
    override_dh_strip_nondeterminism:
    EOF
    patchShebangs usr/bin
  '';

  # debhelper
  nativeBuildInputs = [ makeWrapper ];
  propagatedBuildInputs = [ dpkg debhelper perlPackages.perl ];

  installPhase = ''
    cp -R --preserve=mode usr $out
    mkdir -p $out/share/man/man1
    cp -R *.1 $out/share/man/man1
    # https://superuser.com/a/1274900
    mkdir -p $out/share/equivs/admindir/info
    mkdir -p $out/share/equivs/admindir/updates
    touch $out/share/equivs/admindir/status
  '';

  meta = with lib; {
    description = "Circumvent Debian package dependencies";
    license = licenses.gpl2;
    maintainers = with maintainers; [quentin];
    platforms = with platforms; linux;
  };
}
