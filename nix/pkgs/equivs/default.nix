{lib, stdenv, fetchurl
, makeWrapper, writeShellScript
, perlPackages, dpkg, rsync
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
    substituteInPlace usr/bin/equivs-build usr/bin/equivs-control --replace /usr/share $out/share --replace dpkg-buildpackage ${dpkg}/bin/dpkg-buildpackage --replace "cp -R" "${rsync}/bin/rsync -rltE --chmod=u+w" --replace "cp " "cp --no-preserve=mode "
    patchShebangs usr/bin
  '';

  # debhelper
  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ ] ++
    (with perlPackages; [ perl ]);

  installPhase = ''
    cp -R --preserve=mode usr $out
    mkdir -p $out/share/man/man1
    cp -R *.1 $out/share/man/man1
  '';

  meta = with lib; {
    description = "Circumvent Debian package dependencies";
    license = licenses.gpl2;
    maintainers = with maintainers; [quentin];
    platforms = with platforms; linux;
  };
}
