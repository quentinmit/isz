{lib, stdenv, fetchurl, xz, dpkg
, libxslt, docbook_xsl, makeWrapper, writeShellScript
, python3Packages
, perlPackages, curl, gnupg, diffutils, nano, pkg-config, bash-completion, help2man
, sendmailPath ? "/run/wrappers/bin/sendmail"
}:

let
  sensible-editor = writeShellScript "sensible-editor" ''
    exec ''${EDITOR-${nano}/bin/nano} "$@"
  '';
in stdenv.mkDerivation rec {
  version = "2.3.1";
  pname = "equivs";

  src = fetchurl {
    url = "mirror://debian/pool/main/e/equivs/equivs_${version}.tar.xz";
    hash = "sha256-BXf+KKRXIxT8pZr5U1hnBBtnmUR4bg5Qi6AeHDSQBsI=";
  };

  postPatch = ''
    substituteInPlace Makefile --replace pod2man ${perlPackages.perl}/bin/pod2man
    substituteInPlace usr/bin/equivs-build usr/bin/equivs-control --replace /usr/share $out/share --replace dpkg-buildpackage ${dpkg}/bin/dpkg-buildpackage
    patchShebangs usr/bin
  '';

  # debhelper
  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ ] ++
    (with perlPackages; [ perl ]);

  installPhase = ''
    cp -R usr $out
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
