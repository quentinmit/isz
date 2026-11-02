{ grafanaPlugin, lib }:

grafanaPlugin {
  pname = "equansdatahub-tree-panel";
  inherit (lib.importTOML ./sources.toml) version packages;
}
