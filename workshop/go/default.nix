{ buildGoModule
, stdenv
, lib
}:

buildGoModule rec {
  name = "workshop-go";

  src = builtins.path { path = ./.; name = "workshop-go"; };

  vendorHash = "sha256-4cBdX6IQ0gUq+zXWEJhpklkUn/2cs2Iv3HqjyQEybZ0=";
}
