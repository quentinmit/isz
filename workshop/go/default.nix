{ buildGoModule
, stdenv
, lib
}:

buildGoModule rec {
  name = "workshop-go";

  src = builtins.path { path = ./.; name = "workshop-go"; };

  vendorHash = "sha256-TRY+Ri1kdUlbzPplZ5CMA2Bu7mZKepiuUJhtLnPUrgw=";
}
