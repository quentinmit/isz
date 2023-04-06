{ lib
, stdenv
, python3
, pkgs
}:

python3.pkgs.buildPythonApplication {
  name = "w1-python";

  propagatedBuildInputs = with python3.pkgs; [
    influxdb-client
    w1thermsensor
  ];

  src = ./.;

  format = "other";
  buildPhase = "true";
  installPhase = ''
    mkdir -p $out/bin/
    cp $src/*.py $out/bin/
  '';
}
