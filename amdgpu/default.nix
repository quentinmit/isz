# default.nix
{ lib
, rust-bin
, pciutils
, makeRustPlatform
, makeWrapper
}:

# Modified from https://hoverbear.org/blog/rust-bindgen-in-nix/

let
    cargoToml = builtins.fromTOML (builtins.readFile ./Cargo.toml);
    rust = rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
    rustPlatform = makeRustPlatform {
      cargo = rust;
      rustc = rust;
    };
in
rustPlatform.buildRustPackage {
  pname = cargoToml.package.name;
  inherit (cargoToml.package) version;

  src = ./.;

  cargoHash = "sha256-lREzaDBUMIC8iAT+NBAPqsMgyS5iOtNLSikyPf4R3qs=";

  doCheck = false;

  nativeBuildInputs = [
    makeWrapper
    rustPlatform.bindgenHook
  ];

  postInstall = ''
    wrapProgram $out/bin/amdgpu \
      --set PATH ${lib.makeBinPath [
        pciutils
      ]}
  '';
}
