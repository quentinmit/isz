{ grafanaPlugin }:
{
  marcusolsson-json-datasource = grafanaPlugin {
    pname = "marcusolsson-json-datasource";
    version = "1.3.21";
    zipHash = "sha256-0QEMNc/nFgj3mrtPLU8vea7+n+mGW5pB4GFuG5TUFY8=";
  };
  operato-windrose-panel = grafanaPlugin {
    pname = "operato-windrose-panel";
    version = "1.2.0";
    zipHash = "sha256-fOejV+rLzgj3Zsm6x1OXbk5IqJPNkKXchsWNfDrXe2E=";
    postPatch = ''
      rm MANIFEST.txt
    '';
  };
  volkovlabs-echarts-panel = grafanaPlugin {
    pname = "volkovlabs-echarts-panel";
    version = "6.5.0";
    zipHash = "sha256-yhdZHeT/22cTeoHcXqHT/JbSEdIpJZkAh7YHUALqY3c=";
  };
  grafana-lokiexplore-app = grafanaPlugin {
    pname = "grafana-lokiexplore-app";
    version = "1.0.6";
    zipHash = "sha256-8XQV3wOSYgZwvnjZh4DwsiSBrkCVounGSxg3EVTN5mE=";
  };
}
