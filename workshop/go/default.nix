{ buildGoModule
, stdenv
, lib
}:

buildGoModule rec {
  name = "workshop-go";

  src = builtins.path { path = ./.; name = "workshop-go"; };

  vendorSha256 = "Sg9qkQUdOmlEUVMrMZM+ScsWCk9Vo/jX1TpMesSz39s=";
}
