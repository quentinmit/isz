{ buildGoModule
, stdenv
, lib
}:

buildGoModule rec {
  name = "bedroom-go";

  src = builtins.path { path = ./.; name = "bedroom-go"; };

  vendorHash = "sha256-fSb/Dxy1fYNIJ854VD/sb4tKOHE5r73FrbQNFHUAG0M=";
}
