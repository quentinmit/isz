{ lib, python3Packages }:
with python3Packages;
buildPythonApplication {
  pname = "dashboard";
  version = "0.0.1";
  format = "pyproject";

  propagatedBuildInputs = [
    pillow
    astropy
    influxdb-client
    matplotlib
    more-itertools
    numpy
    paho-mqtt
    cherrypy
    Dozer
  ];

  src = ./.;
}
