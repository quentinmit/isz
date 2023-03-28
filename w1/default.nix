{ lib
, stdenv
, python3
, pkgs
}:

let
  w1thermsensor =
    python3.pkgs.buildPythonPackage rec {
      pname = "w1thermsensor";
      version = "2.0.0";

      src = python3.pkgs.fetchPypi {
        inherit pname version;
        hash = "sha256-EcaEr4B8icbwZu2Ty3z8AAgglf74iZ5BLpLnSOZC2cE=";
      };

      doCheck = false;

      nativeBuildInputs = with python3.pkgs; [ setuptools-scm ];
      propagatedBuildInputs = with python3.pkgs; [ aiofiles click ];
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
