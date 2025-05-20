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

  cargoHash = "sha256-I8pLCvGvWJuWc0dSjWNcYC/6RSH2HJLvvVbc2LyvnR4=";
}
