{ lib
, stdenv
, buildGoModule
, fetchFromGitHub
}:

buildGoModule rec {
  pname = "process-bandwidth";
  version = "0.3.2";

  src = fetchFromGitHub {
    owner = "Ivlyth";
    repo = "process-bandwidth";
    rev = "v${version}";
    sha256 = "5KRDdhAOD809UiPuoJ2EcHqRd9xIs0MQ2yThYI/Foig=";
  };

  vendorSha256 = "B5rhpgfAQ7Xev1fkgLGc2sliJYNyCsDPKV23fnE1KOs=";
}
