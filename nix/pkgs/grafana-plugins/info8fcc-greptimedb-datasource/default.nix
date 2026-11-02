{ grafanaPlugin, fetchzip, lib }:

let
  version = "3.0.3";
in grafanaPlugin {
  pname = "info8fcc-greptimedb-datasource";
  inherit version;
  packages.any = null;
  src = fetchzip {
    url = "https://github.com/GreptimeTeam/greptimedb-grafana-datasource/releases/download/v${version}/info8fcc-greptimedb-datasource-unsigned.zip";
    hash = "sha256-DxwhRuiEA50tQTHdmhnr14GNv2Nd0QrLVg61IMFCIao=";
  };
}
