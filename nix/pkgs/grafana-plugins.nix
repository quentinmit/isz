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
}
