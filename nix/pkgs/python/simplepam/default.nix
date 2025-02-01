{ lib
, linux-pam
, buildPythonPackage
, fetchPypi
}:

buildPythonPackage rec {
  pname = "simplepam";
  version = "0.1.5";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-m03VDaQaBN1q//kyuLfjPAFa8FvrOz5bzTI7ZMI5Cl8=";
  };

  postPatch = ''
    substituteInPlace simplepam.py \
      --replace-fail 'find_library("pam")' '"${lib.getLib linux-pam}/lib/libpam.so"'
  '';
}
