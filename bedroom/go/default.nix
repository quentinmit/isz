{ buildGoModule
, stdenv
, lib
}:

buildGoModule rec {
  name = "bedroom-go";

  src = builtins.path { path = ./.; name = "bedroom-go"; };

  vendorSha256 = "";
}
