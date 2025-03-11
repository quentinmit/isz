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

  postPatch = ''
    substituteInPlace flatpak/hedgemodmanager.desktop \
      --replace-fail /app/bin/ $out/bin/
  '';

  projectFile = "Source/HedgeModManager.UI/HedgeModManager.UI.csproj";
  nugetDeps = ./deps.json; # see "Generating and updating NuGet dependencies" section for details

  dotnet-sdk = dotnetCorePackages.sdk_8_0;
  dotnet-runtime = dotnetCorePackages.runtime_8_0;

  executables = [ "HedgeModManager.UI" ];

  postInstall = ''
    install -m 644 -D flatpak/hedgemodmanager.desktop $out/share/applications/io.github.hedge_dev.hedgemodmanager.desktop
    install -m 444 -D flatpak/hedgemodmanager.png $out/share/icons/hicolor/256x256/apps/io.github.hedge_dev.hedgemodmanager.png
  '';

  # TODO: Install flatpak/hedgemodmanager.png and flatpak/hedgemodmanager.desktop
}
