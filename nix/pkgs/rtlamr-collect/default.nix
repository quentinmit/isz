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

  vendorHash = "sha256-aUuKZaE31PSxJSvvJ+Ag0LXNewYLAC3nuuDV9sLUpJU=";

  meta = with lib; {
    description = "Data aggregation for rtlamr";
    longDescription = ''
      Collect rtlamr data in InfluxDB.
    '';
    homepage = "https://github.com/bemasher/rtlamr-collect";
    license = with licenses; [ agpl3Only ];
  };
}
