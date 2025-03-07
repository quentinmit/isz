{ lib
, buildDotnetModule
, dotnetCorePackages
, fetchFromGitHub
}:

let
  pname = "jellyfin-plugin-sso";
  version = "3.5.2.4";
in buildDotnetModule rec {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "9p4";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-ilpMt/2QbInbRDZMt/W9qwL3D/EOVuZ4jLObdokQ86c=";
  };

  projectFile = "SSO-Auth/SSO-Auth.csproj";
  nugetDeps = ./deps.json; # see "Generating and updating NuGet dependencies" section for details

  dotnet-sdk = dotnetCorePackages.sdk_8_0;
  dotnet-runtime = dotnetCorePackages.runtime_8_0;

#  executables = [ "foo" ]; # This wraps "$out/lib/$pname/foo" to `$out/bin/foo`.
#  executables = []; # Don't install any executables.

#  packNupkg = true; # This packs the project as "foo-0.1.nupkg" at `$out/share`.

#  runtimeDeps = [ ffmpeg ]; # This will wrap ffmpeg's library path into `LD_LIBRARY_PATH`.
}
