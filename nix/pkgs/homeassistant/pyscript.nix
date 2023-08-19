{ stdenv
, lib
, fetchFromGitHub
}:

let
  pname = "pyscript";
  version = "1.5.0";
in
stdenv.mkDerivation {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "custom-components";
    repo = pname;
    rev = version;
    sha256 = "KUx5wPxcXDgDwgskCY0JVTivbfKC87VgNhZrizoi0hg=";
  };

  dontBuild = true;

  installPhase = ''
    mkdir -p $out/custom_components
    cp -av $src/custom_components/pyscript $out/custom_components
  '';

  meta = with lib; {
    description = "Pyscript adds rich Python scripting to HASS";
    homepage = "https://github.com/custom-components/${pname}";
    maintainers = with maintainers; [ quentin ];
    license = licenses.asl20;
  };
}
