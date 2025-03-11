{ lib
, clangStdenv
, lld
, directx-shader-compiler
, curl
, cmake
, ninja
, pkg-config
, gtk3
, wayland-scanner
, sdl3
, wrapGAppsHook
, fetchFromGitHub
, requireFile
, path
, copyDesktopItems
, makeDesktopItem
}:
let
  pname = "UnleashedRecomp";
  version = "1.0.2";
  lld_ = clangStdenv.cc.bintools.override {
    extraBuildCommands = ''
      for ld in $(find ${lld}/bin -name "ld*" -printf "%f\n"); do
        wrap ${clangStdenv.cc.bintools.targetPrefix}$ld \
            ${path + /pkgs/build-support/bintools-wrapper/ld-wrapper.sh} \
            ${lld}/bin/$ld
      done
    '';
  };
  dxc = directx-shader-compiler.overrideAttrs (old: {
    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin $out/lib $dev/include
      cp bin/dx* $out/bin/
      cp lib/libdx*.so* lib/libdx*.*dylib $out/lib/
      ln -s libdxil.so $out/lib/libdxildll.so
      cp -r $src/include/dxc $dev/include/
      runHook postInstall
    '';
  });
  romFiles = builtins.mapAttrs (name: hash: requireFile {
    inherit name hash;
    message = ''
      Building UnleashedRecomp requires the following files from the original game:

      - default.xex
      - default.xexp
      - shader.ar

      Please add them to the nix store with
        nix store add --mode=flat \$file
    '';
  }){
    "default.xex" = "sha256-iaUxKCB6XpMUZUfJKzlrl85wUXet0L2dn2NneENHaLg=";
    "default.xexp" = "sha256-sSu30I53t18HWPewUyJLcd6ZA1kmcSFP5N0iIJeRGhY=";
    "shader.ar" = "sha256-5e/ysO+r1sSv9sVjMpIygQJxUm5P0Kvy3i93MNuLY+U=";
  };
in clangStdenv.mkDerivation {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "hedge-dev";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-nQZPqvXI4AtJ0o6pBgHdfELuE8XzTTkw5kka+cvCwcw=";
    fetchSubmodules = true;
  };

  patches = [
    # From https://github.com/Jujstme/UnleashedRecomp
    ./install-dir.patch
  ];

  postPatch = ''
    mkdir /build/cmake
    cat > /build/cmake/directx-dxc-config.cmake <<EOF
      add_library(Microsoft::DirectXShaderCompiler SHARED IMPORTED)
      set_target_properties(Microsoft::DirectXShaderCompiler PROPERTIES
        IMPORTED_LOCATION                    "${dxc}/lib/libdxcompiler.so"
        IMPORTED_IMPLIB                      "${dxc}/lib/libdxcompiler.so"
        IMPORTED_SONAME                      "libdxcompiler.so"
        INTERFACE_INCLUDE_DIRECTORIES        "${dxc.dev}/include/dxc"
        INTERFACE_LINK_LIBRARIES             "Microsoft::DXIL"
        IMPORTED_LINK_INTERFACE_LANGUAGES    "C")
      add_library(Microsoft::DXIL SHARED IMPORTED)
      set_target_properties(Microsoft::DXIL PROPERTIES
        IMPORTED_LOCATION                    "${dxc}/lib/libdxil.so"
        IMPORTED_IMPLIB                      "${dxc}/lib/libdxil.so"
        IMPORTED_NO_SONAME                   TRUE
        INTERFACE_INCLUDE_DIRECTORIES        "${dxc.dev}/include/dxc"
        IMPORTED_LINK_INTERFACE_LANGUAGES    "C")
      set(DIRECTX_DXC_TOOL "${dxc}/bin/dxc")
    EOF
    sed -i '/file(CHMOD ..DIRECTX_DXC_TOOL./d' UnleashedRecomp/CMakeLists.txt

    ${lib.concatMapStringsSep "\n" (f: "cp ${f} UnleashedRecompLib/private/${f.name}") (builtins.attrValues romFiles)}
  '';

  nativeBuildInputs = [
    copyDesktopItems
    wrapGAppsHook
    cmake
    ninja
    lld_
    pkg-config
    dxc
    wayland-scanner
  ];

  preBuild = ''
    cd ../out/build/linux-release
  '';

  buildInputs = [
    dxc
    curl
    gtk3
  ] ++ sdl3.buildInputs ++ sdl3.propagatedBuildInputs;

  env.NIX_LDFLAGS = sdl3.NIX_LDFLAGS;
  dontPatchELF = true;

  preConfigure = ''
    prependToVar cmakeFlags "-DCMAKE_C_COMPILER_AR=$(command -v $AR)"
    prependToVar cmakeFlags "-DCMAKE_C_COMPILER_RANLIB=$(command -v $RANLIB)"
    prependToVar cmakeFlags "-DCMAKE_CXX_COMPILER_AR=$(command -v $AR)"
    prependToVar cmakeFlags "-DCMAKE_CXX_COMPILER_RANLIB=$(command -v $RANLIB)"
  '';

  cmakeFlags = [
    "--preset=linux-release"
    #"-DENABLE_VCPKG=OFF"
    "-DVCPKG_MANIFEST_INSTALL=OFF"
    #"-DCMAKE_DISABLE_FIND_PACKAGE_directx-dxc=ON"
    #"-DCMAKE_REQUIRE_FIND_PACKAGE_directx-dxc=OFF"
    #"-Ddirectx-dxc_FOUND=ON"
    "-DCMAKE_PREFIX_PATH=/build/cmake"
    #"-DDIRECTX_DXC_TOOL=${directx-shader-compiler}/bin/dxc"
  ];

  ninjaFlags = [
    "-v"
  ];

  desktopItems = [(makeDesktopItem {
    name = "UnleashedRecomp";
    desktopName = "Unleashed Recompiled";
    exec = "UnleashedRecomp";
    type = "Application";
    icon = "UnleashedRecomp";
    categories = [ "Game" ];
    comment = "Static recompilation of Sonic Unleashed.";
    mimeTypes = ["x-scheme-handler/unleashedrecomp"];
  })];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    mv UnleashedRecomp/UnleashedRecomp $out/bin/
    install -m 444 -D ../../../UnleashedRecompResources/images/game_icon.png $out/share/icons/hicolor/128x128/apps/UnleashedRecomp.png

    runHook postInstall
  '';
}
