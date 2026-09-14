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

  cargoHash = "sha256-G9ytiYtJUrSqN0aaBL8bB5D3+1h7gPdE7uiL+1c5sDc=";

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
