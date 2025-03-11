{ lib
, buildDotnetModule
, dotnetCorePackages
, fetchFromGitHub
}:

let
  pname = "HedgeModManager";
  version = "8.0.0-beta4";
in buildDotnetModule rec {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "hedge-dev";
    repo = pname;
    rev = version;
    hash = "sha256-1uwcpeyOxwKI0fyAmchYEMqStF52wXkCZej+ZQ+aFeY=";
  };

  projectFile = "Source/HedgeModManager.UI/HedgeModManager.UI.csproj";
  nugetDeps = ./deps.json; # see "Generating and updating NuGet dependencies" section for details

  dotnet-sdk = dotnetCorePackages.sdk_8_0;
  dotnet-runtime = dotnetCorePackages.runtime_8_0;

  executables = [ "HedgeModManager.UI" ];

  # TODO: Install flatpak/hedgemodmanager.png and flatpak/hedgemodmanager.desktop
}
