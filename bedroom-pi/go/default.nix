{ buildGoModule
, stdenv
, lib
}:

buildGoModule rec {
  name = "bedroom-go";

  src = builtins.path { path = ./.; name = "bedroom-go"; };

  vendorSha256 = "sha256-KixGIlEBms7mZomzTWhYFb3iPYZ2or9pciesvIcQGIs=";
}
