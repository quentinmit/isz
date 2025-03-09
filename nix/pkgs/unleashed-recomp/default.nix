{ lib
, clangStdenv
, lld
, directx-shader-compiler
, curl
, cmake
, ninja
, pkg-config
, gtk3
, pipewire
, wayland
, wayland-protocols
, wayland-scanner
, libxkbcommon
, wrapGAppsHook
, fetchFromGitHub
}:
let
  pname = "UnleashedRecomp";
  version = "1.0.2";
  dxc = directx-shader-compiler.overrideAttrs (old: {
    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin $out/lib $dev/include
      cp bin/dx* $out/bin/
      cp lib/libdx*.so* lib/libdx*.*dylib $out/lib/
      cp -r $src/include/dxc $dev/include/
      runHook postInstall
    '';
  });
in clangStdenv.mkDerivation {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "hedge-dev";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-nQZPqvXI4AtJ0o6pBgHdfELuE8XzTTkw5kka+cvCwcw=";
    fetchSubmodules = true;
  };

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
  '';

  nativeBuildInputs = [
    wrapGAppsHook
    cmake
    ninja
    lld
    pkg-config
    dxc
    wayland-scanner
  ];

  preBuild = ''
    cd ../out/build/linux-release
  '';

  buildInputs = [
    dxc
    gtk3
    pipewire
    wayland
    wayland-protocols
    curl
    libxkbcommon
  ];

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
}
