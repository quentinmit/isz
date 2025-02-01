{ lib
, libraspberrypi
, buildPythonPackage
, fetchPypi
, setuptools
}:

buildPythonPackage rec {
  pname = "vcgencmd";
  version = "0.1.1";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-4Lshr3TX9OBP/pcmKlTLOY+U9ROXF8F1q2bBATEqyUs=";
  };

  postPatch = ''
    substituteInPlace vcgencmd/vcgencmd.py \
      --replace-fail '"vcgencmd"' '"${lib.getBin libraspberrypi}/bin/vcgencmd"'
  '';

  nativeBuildInputs = [
    setuptools
  ];
}
