{ lib
, rustPlatform
, openssl
, pkg-config
}:

let
    cargoToml = builtins.fromTOML (builtins.readFile ./Cargo.toml);
in
rustPlatform.buildRustPackage rec {
  pname = cargoToml.package.name;
  inherit (cargoToml.package) version;

  src = ./.;

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    openssl
  ];

  cargoHash = "sha256-Orsl9SCfR9bDG53BoFeEgU608o9j4lBhHmvQW4piP/U=";
}
