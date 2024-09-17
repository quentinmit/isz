{ lib
, stdenv
, libpulseaudio
, libGL
, cmake
, bison
, flex
, python3
, wrapGAppsHook
, darwin
, fetchFromGitHub
, applyPatches
, pkgs
}:
let
  pname = "Einstein";
  version = "2024.4.22";
  deps = {
    googletest = fetchFromGitHub {
      owner = "google";
      repo = "googletest";
      rev = "release-1.11.0";
      hash = "sha256-SjlJxushfry13RGA7BCjYC9oZqV4z6x8dOiHfl/wpF0=";
    };
    newt64 = applyPatches {
      src = fetchFromGitHub {
        owner = "MatthiasWM";
        repo = "NEWT64";
        rev = "c90572901d7a17561f30b3b50d6f2635bb1345dc";
        hash = "sha256-eV7H5kqesRGIx/t8edO50+0L/SM6tEGaHs9LUCewoFw=";
      };
      postPatch = ''
        sed -i '
          s/\''${CMAKE_CURRENT_SOURCE_DIR}\/src\/version.h$/version.h/;
          s/src\/version.h$/\''${CMAKE_CURRENT_BINARY_DIR}\/version.h/;
          /target_include_directories/{n;i\
          ''${CMAKE_CURRENT_BINARY_DIR}
          }' CMakeLists.txt
      '';
    };
    fltk = (pkgs.callPackage (import "${pkgs.path}/pkgs/development/libraries/fltk/common.nix" {
      version = "1.4.x-2024-09-15";
      rev = "da20d8397df263db882e914405bb03b9792f4692";
      sha256 = "faJFRsL5dnezMvK70UthQYiosVh+on4SWCfxqsZwEew=";
    }) {
      inherit (darwin.apple_sdk.frameworks) ApplicationServices Carbon Cocoa OpenGL;
      withDocs = false; # Don't build correctly
    }).overrideAttrs (old: {
      buildInputs = old.buildInputs ++ (with pkgs; [
        libdecor
        # Wayland
        wayland
        wayland-protocols
        libxkbcommon
        # Cairo
        expat
        xorg.libXdmcp
        # Pango
        pcre2
        libthai
        libdatrie
        # GLib
        libselinux
        libsepol
        util-linuxMinimal
        # GTK
        gtk3
        epoxy
        xorg.libXtst
      ]);
    });
  };
in stdenv.mkDerivation {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "pguyot";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-J6z/6h5ZvbNMaJwkFrH04bs6QTGY+4FilzbTHdYxOVI=";
  };

  buildInputs = [
    deps.fltk
    libGL
    libpulseaudio
  ];

  nativeBuildInputs = [
    wrapGAppsHook
    cmake
    bison
    flex
    python3
  ];

#   preConfigure = ''
#     mkdir -p build/_deps
#     ln -s ${deps.googletest} build/_deps/googletest-src
#   '';
  postPatch = ''
    substituteInPlace CMakeLists.txt \
      --replace-fail "fltk::png fltk::z" ""

    substituteInPlace Emulator/Serial/TPipesSerialPortManager.cpp \
      --replace-fail "[PATH_MAX]" "[PATH_MAX+1]"
  '';

  CXXFLAGS = [
    "-Wno-error=nonnull"
    "-Wno-error=unused-result"
  ];

  cmakeFlags = [
    "-DFETCHCONTENT_TRY_FIND_PACKAGE_MODE=ALWAYS"
    (lib.cmakeBool "CMAKE_FIND_PACKAGE_PREFER_CONFIG" true)
    "-DFLTK_DIR=${deps.fltk}/share/fltk"
    "-DFETCHCONTENT_SOURCE_DIR_GOOGLETEST=${deps.googletest}"
    "-DFETCHCONTENT_SOURCE_DIR_NEWT64=${deps.newt64}"
  ];

  installPhase = ''
    runHook preInstall

    install -vD Einstein $out/bin/Einstein

    runHook postInstall
  '';

  meta = with lib; {
    description = "NewtonOS running on other operating systems";
    homepage = "https://github.com/pguyot/Einstein/";
    license = licenses.gpl2Plus;
    maintainers = [ maintainers.quentin ];
    platforms = platforms.unix;
  };
}
