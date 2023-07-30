{ buildGoModule
, stdenv
, lib
}:

buildGoModule rec {
  name = "workshop-go";

  src = builtins.path { path = ./.; name = "workshop-go"; };

  vendorSha256 = "oN26cnX0tDvQRAymUep5MLK1yvDI/r2MWrisQgFDdwU=";
}
