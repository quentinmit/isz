{ buildGoModule
, stdenv
, lib
, fetchFromGitHub
}:

buildGoModule rec {
  name = "speedtest-influxdb";
  version = "1.1.0";

  src = fetchFromGitHub {
    owner = "QuadStingray";
    repo = "docker-speedtest-influxdb";
    rev = "a9f610d3464d1f98bce8452395207683f61c8983";
    sha256 = "X99hXpqubbOoFnRT2Qv2S/M8nNabIL5GP+VBE+hB73c=";
  };

  vendorHash = "sha256-Avy04f9bBTMvp12RsgtkwmhaGv45RN2OwspPht0vKv8=";

  meta = with lib; {
    description = "Speedtest for InfluxDB";
    longDescription = ''
      Speedtest results to InfluxDB for Grafana.
    '';
    homepage = "https://github.com/QuadStingray/docker-speedtest-influxdb";
    license = with licenses; [ asl20 ];
  };
}
