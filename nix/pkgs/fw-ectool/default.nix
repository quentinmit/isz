{ stdenv
, lib
, fetchFromGitLab
, pkg-config
, hostname
, libftdi1
, libusb1
, cmake
}:

stdenv.mkDerivation {
  pname = "fw-ectool";
  version = "unstable-2024-04-23";

  src = fetchFromGitLab {
    domain = "gitlab.howett.net";
    owner = "DHowett";
    repo = "ectool";
    rev = "39d64fb0e79e874cfe9877af69158fc2520b1a80";
    hash = "sha256-SHRnyqicFlviBDu3aH+uKVUstVxpIhZV6JSuZOgOwXU=";
  };

  nativeBuildInputs = [
    pkg-config
    hostname
    cmake
  ];

  buildInputs = [
    libftdi1
    libusb1
  ];

  installPhase = ''
    install -D src/ectool $out/bin/ectool
  '';

  meta = with lib; {
    description = "EC-Tool adjusted for usage with framework embedded controller";
    homepage = "https://github.com/DHowett/framework-ec";
    license = licenses.bsd3;
    maintainers = [ maintainers.mkg20001 ];
    platforms = platforms.linux;
    mainProgram = "ectool";
  };
}
