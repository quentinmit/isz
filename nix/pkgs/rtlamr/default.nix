{ buildGoModule
, stdenv
, lib
, fetchFromGitHub
}:

buildGoModule rec {
  name = "rtlamr";
  version = "0.9.3";

  src = fetchFromGitHub {
    owner = "bemasher";
    repo = "rtlamr";
    rev = "v${version}";
    sha256 = "0LufLU/wTmCRqTnQBNJg5UnDv0u1Thec5FSWATWqZsQ=";
  };

  vendorHash = "sha256-uT6zfsWgIot0EMNqwtwJNFXN/WaAyOGfcYJjuyOXT4g=";

  meta = with lib; {
    description = "RTL-SDR ERT receiver";
    longDescription = ''
      An rtl-sdr receiver for Itron ERT compatible smart
      meters operating in the 900MHz ISM band.
    '';
    homepage = "https://github.com/bemasher/rtlamr";
    license = with licenses; [ agpl3Only ];
  };
}
