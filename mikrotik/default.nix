{ lib
, stdenv
, python3
, fetchPypi
, pkgs
, buildPythonPackage
}:

let
  routeros-api =
    buildPythonPackage rec {
      pname = "RouterOS-api";
      version = "0.17.0";

      src = fetchPypi {
        inherit pname version;
        hash = "";
      };

      nativeBuildInputs = with pkgs; [ setuptools-scm ];
      propagatedBuildInputs = with pkgs; [ six ];
    };
in
python3.pkgs.buildPythonApplication rec {
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
};
