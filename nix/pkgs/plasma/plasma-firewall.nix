{ mkDerivation
, extra-cmake-modules
, python3
, plasma-framework
, kcmutils

, wrapQtAppsHook
, pkgs
, fetchurl
}:
let
  srcs = import "${pkgs.path}/pkgs/desktops/plasma-5/srcs.nix" {
    inherit fetchurl;
    mirror = "mirror://kde";
  };
in mkDerivation rec {
  pname = "plasma-firewall";
  sname = pname;
  inherit (srcs.${sname}) src version;

  outputs = [ "out" ];

  hasBin = false;
  hasDev = false;

  nativeBuildInputs = [
    extra-cmake-modules
    wrapQtAppsHook
  ];

  buildInputs = [
    kcmutils
    plasma-framework
    python3
  ];
}
