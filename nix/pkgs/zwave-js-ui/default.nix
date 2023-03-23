{ stdenv
, lib
, pkgs
, nodejs
, fetchFromGitHub
}:
stdenv.mkDerivation rec {
  pname = "zwave-js-ui";
  version = "8.11.0";
  src = fetchFromGitHub {
    owner = "zwave-js";
    repo = "zwave-js-ui";
    rev = "v${version}";
    sha256 = "wYPUetdCkhQvgVufTcgkLAj154VK/BqMa46FwV4v7H4=";
  };

  nativeBuildInputs = [
    nodejs
  ];

  buildPhase =
    let
      nodeDependencies = (import ./node-composition.nix {
        inherit pkgs nodejs;
        inherit (stdenv.hostPlatform) system;
      }).nodeDependencies.override (old: {
        # access to path '/nix/store/...-source' is forbidden in restricted mode
        src = src;
        dontNpmInstall = true;
      });
    in
    ''
      runHook preBuild

      export PATH="${nodeDependencies}/bin:${nodejs}/bin:$PATH"

      # https://github.com/parcel-bundler/parcel/issues/8005
      export NODE_OPTIONS=--no-experimental-fetch

      ln -s ${nodeDependencies}/lib/node_modules .

      yarn run build

      runHook postBuild
    '';

  meta = with lib; {
    description = "Z-Wave JS UI";
    longDescription = ''
      Full featured Z-Wave Control Panel UI and MQTT gateway. Built using
      Nodejs, and Vue/Vuetify.
    '';
    homepage = "https://zwave-js.github.io/zwave-js-ui/";
    license = with licenses; [ mit ];
  };
}