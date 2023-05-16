{ buildGoModule
, stdenv
, lib
}:

buildGoModule rec {
  name = "bedroom-go";

  src = builtins.path { path = ./.; name = "bedroom-go"; };

  vendorSha256 = "sha256-UWvD9iUzDIsAY0RikUu4vA1wE0b5zUSOnto7RVjE7b4=";
}
