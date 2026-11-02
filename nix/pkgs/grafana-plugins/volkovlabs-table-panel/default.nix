{ grafanaPlugin, lib }:

grafanaPlugin {
  pname = "volkovlabs-table-panel";
  inherit (lib.importTOML ./sources.toml) version packages;
}
