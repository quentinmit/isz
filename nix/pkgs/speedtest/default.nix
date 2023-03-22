{ buildGoModule
, stdenv
, lib
, fetchFromGitHub
}:

buildGoModule rec {
  name = "speedtest";
  version = "1.1.0";

  src = fetchFromGitHub {
    owner = "QuadStingray";
    repo = "docker-speedtest-influxdb.git";
    rev = "a9f610d3464d1f98bce8452395207683f61c8983";
    sha256 = "";
  };

  vendorSha256 = "";

  meta = with lib; {
    description = "Speedtest for InfluxDB";
    longDescription = ''
      Speedtest results to InfluxDB for Grafana.
    '';
    homepage = "https://github.com/QuadStingray/docker-speedtest-influxdb";
    license = with licenses; [ apache2 ];
  };
}
