{ lib, stdenv
, fetchFromGitHub
, cmake
, pkg-config
, orcania
, yder
, libmicrohttpd
, jansson
, gnutls, libtasn1, p11-kit
, libgcrypt
, curl
, zlib
, check, subunit
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "ulfius";
  version = "2.7.15";

  src = fetchFromGitHub {
    owner = "babelouest";
    repo  = "ulfius";
    rev   = "v${finalAttrs.version}";
    hash  = "sha256-YvMhcobvTEm4LxhNxi1MJX8N7VAB3YOvp+LxioJrKHU=";
  };

  nativeBuildInputs = [ cmake pkg-config ];

  buildInputs = [
    libtasn1 p11-kit
    libgcrypt
    curl
  ];

  propagatedBuildInputs = [
    gnutls
    jansson
    libmicrohttpd
    orcania
    yder
    zlib
  ];

  cmakeFlags = lib.optional finalAttrs.doCheck [
    "-DBUILD_ULFIUS_TESTING=ON"
  ];

  doCheck = true;
  checkInputs = [ check subunit ];

  # TODO: Update cmake hook to make it simpler to selectively disable cmake tests: #113829
  checkPhase = let
    disabledTests = [
      "example_callbacks" # attempts to bind to port 8080
      "core"  # test_ulfius_request_limits, test/core.c:693
    ];
  in ''
    runHook preCheck

    # certificates aren't created automatically when tests are run with ctest
    cd ../test
    ./cert/create-cert.sh
    cd -

    ctest --output-on-failure -E '^${lib.concatStringsSep "|" disabledTests}$'
    runHook postCheck
  '';

  meta = with lib; {
    description = "HTTP Framework for REST Applications in C";
    longDescription = ''
      Web Framework to build REST APIs, Webservices or any HTTP endpoint in 
      C language. 
      Used to facilitate creation of web applications in C programs with a 
      small memory footprint, as in embedded systems applications. 
      Can stream large amount of data, integrate JSON data with Jansson, and 
      create websocket services.
    '';
    homepage = "https://github.com/babelouest/ulfius";
    changelog = "https://github.com/babelouest/ulfius/releases/tag/v${finalAttrs.version}";
    license = licenses.lgpl21Only;
    platforms = platforms.all;
    maintainers = with maintainers; [ kazenyuk ];
  };
})
