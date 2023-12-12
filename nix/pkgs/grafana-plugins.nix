{ grafanaPlugin }:
{
  fetzerch-sunandmoon-datasource = grafanaPlugin {
    pname = "fetzerch-sunandmoon-datasource";
    version = "0.3.0";
    zipHash = "sha256-zvZ8h4lM3DGr11XV2nBxmY4f+OWwQgCNrLZXoqOTBFQ=";
  };
  marcusolsson-json-datasource = grafanaPlugin {
    pname = "marcusolsson-json-datasource";
    version = "1.3.9";
    zipHash = "sha256-N/Bngnjv0lLanQ8ucqsMpTm1iqa+MEigqM2O+/TG9J4=";
  };
  mxswat-separator-panel = grafanaPlugin {
    pname = "mxswat-separator-panel";
    version = "1.0.1";
    zipHash = "sha256-rRWnaCX/P+joEU9kLcl8D2SFSTlmMlhvQ2/YJSFVxZ8=";
  };
  operato-windrose-panel = grafanaPlugin {
    pname = "operato-windrose-panel";
    version = "1.1.1";
    zipHash = "sha256-/iUO/an2CFPbx9Z3SU2EXixgMM4/1goi5c40TZ8RC/g=";
    postPatch = ''
      rm MANIFEST.txt
    '';
  };
  grafana-mqtt-datasource = grafanaPlugin {
    pname = "grafana-mqtt-datasource";
    version = "1.0.0-beta.3";
    zipHash = {
      # TODO: Build from source
      aarch64-linux = "sha256-Vsu7yQydekhqyDqpbW+rcFmEXEyJUfBINml6jR2HmaU=";
      aarch64-darwin = "sha256-UfRAttBgmMpIGval1ACspj7QqRa26LJk7vD1WWM8Hmc=";
      x86_64-linux = "sha256-qkCnN6Xfgzo6pargynBOO4HvSp/7YTMnIJDeycMaiRw=";
      x86_64-darwin = "sha256-o7Jx4H4H1gykjVYvS1htO9WJDlKUzUSMYjADr6v5jGM=";
    };
  };
}
