{ grafanaPlugin, lib }:

grafanaPlugin {
  pname = "operato-windrose-panel";
  inherit (lib.importTOML ./sources.toml) version packages;
  postPatch = ''
    rm MANIFEST.txt
  '';
}
