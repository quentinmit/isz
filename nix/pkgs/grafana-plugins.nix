{ grafanaPlugin }:
{
  operato-windrose-panel = grafanaPlugin {
    pname = "operato-windrose-panel";
    version = "1.2.0";
    zipHash = "sha256-fOejV+rLzgj3Zsm6x1OXbk5IqJPNkKXchsWNfDrXe2E=";
    postPatch = ''
      rm MANIFEST.txt
    '';
  };
  grafana-pyroscope-app = grafanaPlugin {
    pname = "grafana-pyroscope-app";
    version = "1.1.0";
    zipHash = "sha256-kgyXNrvDac1R72BLUiTOQoHacaxgtvLtgN+Fj53Xf9o=";
  };
  volkovlabs-table-panel = grafanaPlugin {
    pname = "volkovlabs-table-panel";
    version = "3.6.5";
    zipHash = "sha256-vRifj6rWjRuav4gshVSBN8d3GQlCBiuoAhqInBcneX0=";
  };
  equansdatahub-tree-panel = grafanaPlugin {
    pname = "equansdatahub-tree-panel";
    version = "1.7.7";
    zipHash = "sha256-43j6Z9vcUTmxlK3Fug3BrdwvAaED9RE6ouvd33hXIqA=";
  };
}
