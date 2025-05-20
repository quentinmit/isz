{ lib
, stdenv
, python3
, pkgs
}:

python3.pkgs.buildPythonApplication {
  name = "mikrotik-python";

  propagatedBuildInputs = with python3.pkgs; [
    aiohttp
    httpx
    influxdb-client
    routeros-api
    pyparsing
    more-itertools
  ];

  src = ./.;

  format = "other";
  buildPhase = "true";
  installPhase = ''
    mkdir -p $out/bin/
    cp $src/*.py $out/bin/
  '';
}
