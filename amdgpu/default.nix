# default.nix
{ lib
, rust-bin
, pciutils
, makeRustPlatform
, makeWrapper
, stdenv
, hostPlatform
, llvmPackages
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
rustPlatform.buildRustPackage rec {
  pname = cargoToml.package.name;
  inherit (cargoToml.package) version;

  src = ./.;

  #cargoSha256 = lib.fakeSha256;
  cargoSha256 = "dEY1Krv+fkfeW5JAtsVJOOYK/OYKYskVVQ3puyxip8Q=";

  LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";
  doCheck = false;

  preBuild = ''
    # From: https://github.com/NixOS/nixpkgs/blob/1fab95f5190d087e66a3502481e34e15d62090aa/pkgs/applications/networking/browsers/firefox/common.nix#L247-L253
    # Set C flags for Rust's bindgen program. Unlike ordinary C
    # compilation, bindgen does not invoke $CC directly. Instead it
    # uses LLVM's libclang. To make sure all necessary flags are
    # included we need to look in a few places.
    export BINDGEN_EXTRA_CLANG_ARGS="$(< ${stdenv.cc}/nix-support/libc-crt1-cflags) \
      $(< ${stdenv.cc}/nix-support/libc-cflags) \
      $(< ${stdenv.cc}/nix-support/cc-cflags) \
      $(< ${stdenv.cc}/nix-support/libcxx-cxxflags) \
      ${lib.optionalString stdenv.cc.isClang "-idirafter ${stdenv.cc.cc}/lib/clang/${lib.getVersion stdenv.cc.cc}/include"} \
      ${lib.optionalString stdenv.cc.isGNU "-isystem ${stdenv.cc.cc}/include/c++/${lib.getVersion stdenv.cc.cc} -isystem ${stdenv.cc.cc}/include/c++/${lib.getVersion stdenv.cc.cc}/${stdenv.hostPlatform.config} -idirafter ${stdenv.cc.cc}/lib/gcc/${stdenv.hostPlatform.config}/${lib.getVersion stdenv.cc.cc}/include"} \
    "
  '';

  shellHook = preBuild;

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    wrapProgram $out/bin/amdgpu \
      --set PATH ${lib.makeBinPath [
        pciutils
      ]}
  '';
}
