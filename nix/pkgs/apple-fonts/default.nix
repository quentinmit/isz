{ callPackage
, fetchurl
}:
{
  SF-Pro = callPackage ./mk-font-package.nix {
    name = "SF-Pro";
    src = fetchurl {
      url = "https://devimages-cdn.apple.com/design/resources/download/SF-Pro.dmg";
      hash = "sha256-Lk14U5iLc03BrzO5IdjUwORADqwxKSSg6rS3OlH9aa4=";
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
      hash = "sha256-CMNP+sL5nshwK0lGBERp+S3YinscCGTi1LVZVl+PuOM=";
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
