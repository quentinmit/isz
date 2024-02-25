{ mkDerivation, async, base, base16, base32, bytestring, charset
, fetchgit, http-client, http-types, lib, managed, megaparsec, mtl
, network, nix, optparse-applicative, tasty-bench, temporary, text
, turtle, vector, wai, wai-extra, warp, warp-tls
}:
mkDerivation {
  pname = "nix-serve-ng";
  version = "1.0.1";
  src = fetchgit {
    url = "https://github.com/aristanetworks/nix-serve-ng/";
    sha256 = "070wq5s6hrl5q8717slqhg87wn1vgz0xfd7lpvhq2k0dg2l80n5c";
    rev = "4d9eacfcf753acbcfa0f513bec725e9017076270";
    fetchSubmodules = true;
  };
  isLibrary = false;
  isExecutable = true;
  executableHaskellDepends = [
    base base16 base32 bytestring charset http-types managed megaparsec
    mtl network optparse-applicative vector wai wai-extra warp warp-tls
  ];
  executablePkgconfigDepends = [ nix ];
  benchmarkHaskellDepends = [
    async base bytestring http-client tasty-bench temporary text turtle
    vector
  ];
  description = "A drop-in replacement for nix-serve that's faster and more stable";
  license = lib.licenses.bsd3;
  mainProgram = "nix-serve";
}
