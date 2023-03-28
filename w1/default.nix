{ lib
, stdenv
, python3
, pkgs
}:

let
  routeros-api =
    python3.pkgs.buildPythonPackage rec {
      pname = "RouterOS-api";
      version = "0.17.0";

      src = python3.pkgs.fetchPypi {
        inherit pname version;
        hash = "sha256-G5iYRg7MRme1Tkd9SVt0wvJK4KrEyQ3Q5i8j7H6uglI=";
      };

      doCheck = false;

      nativeBuildInputs = with python3.pkgs; [ setuptools-scm ];
      propagatedBuildInputs = with python3.pkgs; [ six ];
    };
in
python3.pkgs.buildPythonApplication rec {
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
