{
  callPackage,
}:
{
  operato-windrose-panel = callPackage ./operato-windrose-panel { };
  volkovlabs-table-panel = callPackage ./volkovlabs-table-panel { };
  equansdatahub-tree-panel = callPackage ./equansdatahub-tree-panel { };
  info8fcc-greptimedb-datasource = callPackage ./info8fcc-greptimedb-datasource { };
}
