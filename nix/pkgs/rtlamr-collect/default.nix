{ buildGoModule
, stdenv
, lib
, fetchFromGitHub
}:

buildGoModule rec {
  name = "rtlamr-collect";
  version = "1.0.3";

  src = fetchFromGitHub {
    owner = "bemasher";
    repo = "rtlamr-collect";
    rev = "v${version}";
    sha256 = "7efg0eMVE+qm2OFXO64KxRW5AsTSVSLIl4kw2vJb4Jo=";
  };

  vendorSha256 = "";

  meta = with lib; {
    description = "Data aggregation for rtlamr";
    longDescription = ''
      Collect rtlamr data in InfluxDB.
    '';
    homepage = "https://github.com/bemasher/rtlamr-collect";
    license = with licenses; [ agpl3Only ];
  };
}
