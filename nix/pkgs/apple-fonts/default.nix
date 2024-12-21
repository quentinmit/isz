{ callPackage
, fetchurl
}:
{
  SF-Pro = callPackage ./mk-font-package.nix {
    name = "SF-Pro";
    src = fetchurl {
      url = "https://devimages-cdn.apple.com/design/resources/download/SF-Pro.dmg";
      hash = "sha256-IccB0uWWfPCidHYX6sAusuEZX906dVYo8IaqeX7/O88=";
    };
  };
  SF-Mono = callPackage ./mk-font-package.nix {
    name = "SF-Mono";
    src = fetchurl {
      url = "https://devimages-cdn.apple.com/design/resources/download/SF-Mono.dmg";
      hash = "sha256-bUoLeOOqzQb5E/ZCzq0cfbSvNO1IhW1xcaLgtV2aeUU=";
    };
  };
  SF-Compact = callPackage ./mk-font-package.nix {
    name = "SF-Compact";
    src = fetchurl {
      url = "https://devimages-cdn.apple.com/design/resources/download/SF-Compact.dmg";
      hash = "sha256-PlraM6SwH8sTxnVBo6Lqt9B6tAZDC//VCPwr/PNcnlk=";
    };
  };
  NY = callPackage ./mk-font-package.nix {
    name = "NY";
    src = fetchurl {
      url = "https://devimages-cdn.apple.com/design/resources/download/NY.dmg";
      hash = "sha256-HC7ttFJswPMm+Lfql49aQzdWR2osjFYHJTdgjtuI+PQ=";
    };
  };
}
