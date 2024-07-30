{ buildHomeAssistantComponent
, lib
, croniter
, watchdog
, fetchFromGitHub
}:

let
  owner = "custom-components";
  domain = "pyscript";
  version = "1.5.0";
in
buildHomeAssistantComponent {
  inherit owner domain version;

  src = fetchFromGitHub {
    owner = "custom-components";
    repo = domain;
    rev = version;
    sha256 = "KUx5wPxcXDgDwgskCY0JVTivbfKC87VgNhZrizoi0hg=";
  };

  propagatedBuildInputs = [
    croniter
    watchdog
  ];

  dontCheckManifest = true; # Wants old versions of croniter and watchdog

  meta = with lib; {
    description = "Pyscript adds rich Python scripting to HASS";
    homepage = "https://github.com/custom-components/${domain}";
    maintainers = with maintainers; [ quentin ];
    license = licenses.asl20;
  };
}
