{ buildGoModule
, stdenv
, lib
}:

buildGoModule rec {
  name = "bedroom-go";

  src = builtins.path { path = ./.; name = "bedroom-go"; };

  vendorHash = "sha256-1Kv8FJfWezjrmZDSqftb2WkxR3dqV8hMhwQ6uR4BMPw=";
}
